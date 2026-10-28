#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <map>
#include <optional>
#include <vector>

// One instance per remote speaker, confined to the audio queue. Sequence units
// are Mumble's 10 ms frames. No periodic timer is needed while the queue is empty.
class MLAdaptiveJitterBuffer {
public:
    struct Packet { uint64_t sequence=0; unsigned ticks=0; bool terminator=false; std::vector<uint8_t> bytes; double arrived=0; bool reset=false; };
    static constexpr size_t capacity=12;
    static constexpr double maximumAge=.12;
    bool push(Packet packet,double now) {
        if(packet.sequence>UINT64_MAX-12 || packet.bytes.size()>8192 || packet.ticks>12 || (packet.bytes.empty() && !packet.terminator))return false;
        if(!initialized || now-lastArrival>.25){
            packets.clear();started=false;resetPending=true;initialized=true;baseSequence=packet.sequence;baseArrival=now;
            measured=false;jitter*=.5;
        }
        if(started && packet.sequence<expected)return false;
        auto duplicate=packets.find(packet.sequence);
        if(duplicate!=packets.end()){
            // An empty end marker and the next utterance can share a frame
            // number. Preserve the audio rather than treating it as a replay.
            if(duplicate->second.bytes.empty() && !packet.bytes.empty()){
                packet.arrived=now;duplicate->second=std::move(packet);return true;
            }
            duplicate->second.terminator|=packet.terminator;return false;
        }
        if(measured && packet.sequence>measuredSequence){
            double deviation=std::abs((now-measuredArrival)-(double(packet.sequence)-double(measuredSequence))*.01);
            jitter+=(std::min(deviation,.1)-jitter)*.125;
        }
        if(!measured || packet.sequence>measuredSequence){measured=true;measuredSequence=packet.sequence;measuredArrival=now;}
        lastArrival=now;packet.arrived=now;
        double nominal=baseArrival+targetDelay()+(double(packet.sequence)-double(baseSequence))*.01;
        if(packets.size()>=capacity || (started && packet.sequence>expected && packet.sequence-expected>24) || now-nominal>maximumAge){
            packets.clear();started=false;resetPending=true;baseSequence=packet.sequence;baseArrival=now;
        }
        if(!started)baseSequence=std::min(baseSequence,packet.sequence);
        packets.emplace(packet.sequence,std::move(packet));return true;
    }
    double targetDelay() const {return std::clamp(.02+4*jitter,.02,.08);}
    std::optional<double> nextDeadline() const {
        if(packets.empty())return {};
        const auto &packet=packets.begin()->second;
        return std::min(baseArrival+targetDelay()+(double(packet.sequence)-double(baseSequence))*.01,packet.arrived+maximumAge);
    }
    std::optional<Packet> pop(double now) {
        while(!packets.empty()){
            if(now+1e-6<*nextDeadline())return {};
            auto node=packets.extract(packets.begin());Packet packet=std::move(node.mapped());
            if(now-packet.arrived>maximumAge || (started && packet.sequence<expected))continue;
            started=true;expected=packet.sequence+packet.ticks;packet.reset=resetPending;resetPending=false;return packet;
        }
        return {};
    }
    size_t size() const{return packets.size();}
private:
    std::map<uint64_t,Packet> packets;
    bool initialized=false,started=false,measured=false,resetPending=false;
    uint64_t baseSequence=0,expected=0,measuredSequence=0;
    double baseArrival=0,lastArrival=0,measuredArrival=0,jitter=0;
};
