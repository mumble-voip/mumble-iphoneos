#pragma once
#include <chrono>

// Stay below the protocol's 30-second idle timeout without waking the radio every 5 seconds.
constexpr std::chrono::seconds MLKeepaliveInterval(bool synchronized,
    std::chrono::steady_clock::time_point now, std::chrono::steady_clock::time_point lastVoice) {
    bool active=lastVoice!=std::chrono::steady_clock::time_point{} && now-lastVoice<std::chrono::seconds(5);
    return std::chrono::seconds(synchronized && !active ? 15 : 5);
}
