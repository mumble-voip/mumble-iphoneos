#pragma once
#import <AVFoundation/AVFoundation.h>
#include <array>
#include <atomic>
#include <cstring>
#include <vector>

// One input-tap producer and one audio-queue consumer. Allocate PCM storage
// during engine setup; publishing and copying a callback never allocates or locks.
class MLCaptureBufferQueue {
    static_assert(std::atomic_size_t::is_always_lock_free);
public:
    static constexpr size_t slotCount=4;
    struct Slot {
        AVAudioPCMBuffer *__strong buffer=nil;
        AudioBufferList *buffers=nullptr;
        std::vector<UInt32> capacities;
        AVAudioFrameCount frames=0;
    };
    MLCaptureBufferQueue(AVAudioFormat *format, AVAudioFrameCount capacity): capacity(capacity) {
        stride=format.streamDescription->mBytesPerFrame;
        valid=stride>0;
        for (auto &slot:slots) {
            slot.buffer=[[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:capacity];
            if (!slot.buffer) { valid=false; break; }
            slot.buffer.frameLength=capacity;
            slot.buffers=slot.buffer.mutableAudioBufferList;
            for (UInt32 i=0;i<slot.buffers->mNumberBuffers;++i)
                slot.capacities.push_back(slot.buffers->mBuffers[i].mDataByteSize);
        }
    }
    bool push(const AudioBufferList &input, AVAudioFrameCount frames, AVAudioFrameCount offset=0) {
        if (!valid || !frames || frames>capacity) return false;
        size_t next=written.load(std::memory_order_relaxed);
        if (next-read.load(std::memory_order_acquire)>=slotCount) return false;
        Slot &slot=slots[next%slotCount];
        if (input.mNumberBuffers!=slot.buffers->mNumberBuffers) return false;
        size_t bytes=(size_t)frames*stride, start=(size_t)offset*stride;
        for (UInt32 i=0;i<input.mNumberBuffers;++i) {
            const AudioBuffer &source=input.mBuffers[i];
            if (!source.mData || start>source.mDataByteSize || bytes>source.mDataByteSize-start || bytes>slot.capacities[i]) return false;
        }
        for (UInt32 i=0;i<input.mNumberBuffers;++i)
            std::memcpy(slot.buffers->mBuffers[i].mData,static_cast<const char *>(input.mBuffers[i].mData)+start,bytes);
        slot.frames=frames;
        written.store(next+1,std::memory_order_release);
        return true;
    }
    Slot *front() {
        size_t next=read.load(std::memory_order_relaxed);
        return next==written.load(std::memory_order_acquire) ? nullptr : &slots[next%slotCount];
    }
    void pop() { read.store(read.load(std::memory_order_relaxed)+1,std::memory_order_release); }
    const AVAudioFrameCount capacity;
    bool valid=false;
private:
    UInt32 stride=0;
    std::array<Slot,slotCount> slots;
    alignas(64) std::atomic_size_t written{0};
    alignas(64) std::atomic_size_t read{0};
};
