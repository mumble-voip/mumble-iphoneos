#include "MLCaptureBufferQueue.hpp"
#include <cassert>
#include <cstdio>
#include <thread>

int main() { @autoreleasepool {
    AVAudioFormat *format=[[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:48000 channels:1 interleaved:NO];
    AVAudioPCMBuffer *input=[[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:1024];
    input.frameLength=1024;
    MLCaptureBufferQueue queue(format,128);
    assert(queue.valid && !queue.front());
    std::array<const void *,MLCaptureBufferQueue::slotCount> identities;
    for (size_t i=0;i<MLCaptureBufferQueue::slotCount;++i) {
        input.floatChannelData[0][0]=(float)i;
        assert(queue.push(*input.audioBufferList,1));
    }
    assert(!queue.push(*input.audioBufferList,1));
    input.floatChannelData[0][0]=-1;
    for (size_t i=0;i<MLCaptureBufferQueue::slotCount;++i) {
        auto *slot=queue.front(); assert(slot && slot->frames==1);
        assert(slot->buffer.floatChannelData[0][0]==i);
        identities[i]=(__bridge const void *)slot->buffer;
        queue.pop();
    }
    for (size_t i=0;i<100000;++i) {
        input.floatChannelData[0][0]=(float)i;
        AVAudioFrameCount frames=(AVAudioFrameCount)(i%128)+1;
        assert(queue.push(*input.audioBufferList,frames));
        auto *slot=queue.front(); assert(slot && slot->frames==frames && slot->buffer.floatChannelData[0][0]==i);
        slot->buffer.frameLength=slot->frames;
        assert((__bridge const void *)slot->buffer==identities[i%MLCaptureBufferQueue::slotCount]);
        queue.pop();
    }
    assert(!queue.front() && !queue.push(*input.audioBufferList,129));
    assert(!queue.push(*input.audioBufferList,128,1000));
    AudioBufferList invalid={1,{{1,sizeof(float)-1,input.floatChannelData[0]}}};
    assert(!queue.push(invalid,1) && !queue.front());
    for (NSUInteger i=0;i<1024;++i) input.floatChannelData[0][i]=(float)i;
    assert(queue.push(*input.audioBufferList,128,512));
    auto *chunk=queue.front();
    assert(chunk->frames==128 && chunk->buffer.floatChannelData[0][0]==512 && chunk->buffer.floatChannelData[0][127]==639);
    queue.pop();
    printf("PASS: 100000 callbacks reuse four buffers; bounded overflow, invalid sizes and large-buffer slicing\n");

    for (bool interleaved:{false,true}) {
        AVAudioFormat *stereo=[[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:interleaved];
        AVAudioPCMBuffer *source=[[AVAudioPCMBuffer alloc] initWithPCMFormat:stereo frameCapacity:64]; source.frameLength=64;
        for (UInt32 i=0;i<source.mutableAudioBufferList->mNumberBuffers;++i)
            std::memset(source.mutableAudioBufferList->mBuffers[i].mData,0x35+i,source.mutableAudioBufferList->mBuffers[i].mDataByteSize);
        MLCaptureBufferQueue stereoQueue(stereo,64);
        assert(stereoQueue.push(*source.audioBufferList,64));
        auto *slot=stereoQueue.front(); slot->buffer.frameLength=slot->frames;
        for (UInt32 i=0;i<source.audioBufferList->mNumberBuffers;++i)
            assert(!std::memcmp(source.audioBufferList->mBuffers[i].mData,slot->buffer.audioBufferList->mBuffers[i].mData,source.audioBufferList->mBuffers[i].mDataByteSize));
        stereoQueue.pop();
    }
    printf("PASS: 44.1kHz interleaved and planar stereo preserve all channels\n");

    constexpr size_t count=20000;
    const AudioBufferList *source=input.audioBufferList;
    float *samples=input.floatChannelData[0];
    std::thread producer([&] {
        for (size_t i=0;i<count;++i) {
            samples[0]=(float)i;
            while (!queue.push(*source,1)) std::this_thread::yield();
        }
    });
    for (size_t i=0;i<count;++i) {
        MLCaptureBufferQueue::Slot *slot;
        while (!(slot=queue.front())) std::this_thread::yield();
        assert(slot->frames==1 && slot->buffer.floatChannelData[0][0]==i);
        queue.pop();
    }
    producer.join(); assert(!queue.front());
    printf("PASS: concurrent capture and DSP retain FIFO order without overwriting in-use PCM\n");
} }
