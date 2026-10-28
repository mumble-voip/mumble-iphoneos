#include "MLAdaptiveJitterBuffer.hpp"
#include <cassert>
#include <cstdio>
static MLAdaptiveJitterBuffer::Packet packet(uint64_t sequence){return {sequence,2,false,{1,2,3},0};}
int main(){
    MLAdaptiveJitterBuffer buffer;
    assert(buffer.push(packet(0),0));assert(!buffer.pop(.019));
    assert(buffer.push(packet(4),.025));assert(buffer.push(packet(2),.030));
    assert(!buffer.push(packet(2),.031));
    auto first=buffer.pop(.090),second=buffer.pop(.090),third=buffer.pop(.090);
    assert(first && first->sequence==0 && second && second->sequence==2 && third && third->sequence==4);
    assert(!buffer.push(packet(2),.10));assert(!buffer.nextDeadline());
    std::puts("PASS jitter: short reordering, duplicate/late rejection and no idle timer");
    MLAdaptiveJitterBuffer reversed;
    assert(reversed.push(packet(2),1));assert(reversed.push(packet(0),1.005));
    assert(!reversed.pop(1.019));assert(reversed.pop(1.025)->sequence==0);
    assert(reversed.pop(1.05)->sequence==2);
    assert(reversed.push(packet(0),2));assert(reversed.pop(2.1)->sequence==0);
    std::puts("PASS jitter: first packets arriving backwards and a restarted talkspurt");
    MLAdaptiveJitterBuffer marker;
    auto end=packet(0);end.bytes.clear();end.ticks=0;end.terminator=true;
    assert(marker.push(end,3));assert(marker.push(packet(0),3.005));
    auto beginning=marker.pop(3.03);assert(beginning && !beginning->bytes.empty() && beginning->reset);
    assert(marker.push(packet(2),3.22));auto shifted=marker.pop(3.31);assert(shifted && shifted->reset);
    std::puts("PASS jitter: shared end/start sequence keeps speech; sustained timing shifts rebuffer within bounds");
    MLAdaptiveJitterBuffer adaptive;
    for(unsigned i=0;i<20;i++){double now=i*.02;assert(adaptive.push(packet(i*2),now));assert(adaptive.pop(now+.021));}
    assert(adaptive.targetDelay()<=.021);
    assert(adaptive.push(packet(40),.48));assert(adaptive.targetDelay()>.04 && adaptive.targetDelay()<=.08);
    for(unsigned i=21;i<150;i++){
        double now=.48+(i-20)*.02;assert(adaptive.push(packet(i*2),now));
        adaptive.pop(now+.08);assert(adaptive.targetDelay()>=.02 && adaptive.targetDelay()<=.08);
    }
    assert(adaptive.targetDelay()<.025);
    std::puts("PASS jitter: delay adapts to variation and decays to the 20 ms baseline");
    MLAdaptiveJitterBuffer bounded;
    for(unsigned i=0;i<200;i++){assert(bounded.push(packet(i*2),5));assert(bounded.size()<=MLAdaptiveJitterBuffer::capacity);}
    assert(!bounded.pop(5.121));assert(bounded.size()==0);
    auto invalid=packet(0);invalid.bytes.resize(8193);assert(!bounded.push(invalid,6));
    invalid=packet(0);invalid.ticks=13;assert(!bounded.push(invalid,6));
    std::puts("PASS jitter: burst/age/data bounds prevent growing playback latency");
}
