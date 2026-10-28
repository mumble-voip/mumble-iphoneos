// Mumble's datagram nonce/replay envelope; AES-OCB2 is provided by libmumble.
#pragma once
#include <mumble/CryptOCB2.hpp>
#include <array>
#include <algorithm>
#include <cstdint>

class MLVoiceCrypt {
public:
    bool setup(mumble::BufViewConst key, mumble::BufViewConst outbound, mumble::BufViewConst inbound) {
        if (key.size()!=16 || outbound.size()!=16 || inbound.size()!=16) return false;
        valid = encryptor.setKey(key) && decryptor.setKey(key);
        std::copy(outbound.begin(),outbound.end(),sendNonce.begin());
        resync(inbound);
        return valid;
    }
    bool resync(mumble::BufViewConst nonce) {
        if (nonce.size()!=16) return false;
        std::copy(nonce.begin(),nonce.end(),receiveNonce.begin()); seen.fill(false); return true;
    }
    mumble::Buf encrypt(mumble::BufViewConst data) {
        if (!valid || data.empty()) return {};
        increment(sendNonce,0);
        encryptor.setNonce(sendNonce);
        mumble::Buf packet(data.size()+4), tag(16);
        if (encryptor.encrypt(mumble::BufView(packet).subspan(4),data,tag)!=data.size()) return {};
        packet[0]=sendNonce[0]; std::copy_n(tag.begin(),3,packet.begin()+1); return packet;
    }
    mumble::Buf decrypt(mumble::BufViewConst packet) {
        if (!valid || packet.size()<=4) return {};
        auto candidate=receiveNonce;
        int low=std::to_integer<uint8_t>(packet[0]), current=std::to_integer<uint8_t>(candidate[0]);
        int diff=((low-current+128)&255)-128;
        if (!diff || diff < -30) return {};
        bool late=diff<0;
        if (late && low>current) decrement(candidate,1);
        else if (!late && low<current) increment(candidate,1);
        candidate[0]=packet[0];
        if (seen[low] && history[low]==candidate) return {};
        decryptor.setNonce(candidate);
        mumble::Buf plain(packet.size()-4);
        if (decryptor.decrypt(plain,packet.subspan(4),packet.subspan(1,3))!=plain.size()) return {};
        history[low]=candidate; seen[low]=true;
        if (!late) receiveNonce=candidate;
        ++good; if (late) ++latePackets; else lost+=static_cast<uint32_t>(diff-1);
        return plain;
    }
    bool valid=false;
    uint32_t good=0, latePackets=0, lost=0;
    std::array<std::byte,16> sendNonce{}, receiveNonce{};
private:
    static void increment(std::array<std::byte,16> &nonce, size_t start) {
        for (size_t i=start;i<nonce.size();++i) {
            nonce[i]=std::byte(static_cast<uint8_t>(std::to_integer<uint8_t>(nonce[i])+1));
            if (nonce[i]!=std::byte{0}) break;
        }
    }
    static void decrement(std::array<std::byte,16> &nonce, size_t start) {
        for (size_t i=start;i<nonce.size();++i) {
            nonce[i]=std::byte(static_cast<uint8_t>(std::to_integer<uint8_t>(nonce[i])-1));
            if (nonce[i]!=std::byte{255}) break;
        }
    }
    mumble::CryptOCB2 encryptor, decryptor;
    std::array<std::array<std::byte,16>,256> history{};
    std::array<bool,256> seen{};
};
