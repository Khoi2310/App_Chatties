#ifndef CHATTIES_AUDIO_PROCESSOR_H
#define CHATTIES_AUDIO_PROCESSOR_H

#include <portaudio.h>
#include <vector>
#include <memory>
#include <cstdint>

namespace chatties {
namespace server {

class AudioProcessor {
public:
    AudioProcessor();
    ~AudioProcessor();
    
    bool initialize();
    void shutdown();
    
    bool start_recording();
    bool stop_recording();
    
    bool start_playback();
    bool stop_playback();
    
    std::vector<float> get_audio_frame();
    void queue_audio_frame(const std::vector<float>& frame);
    
private:
    PaStream* recording_stream_;
    PaStream* playback_stream_;
    bool initialized_;
};

} // namespace server
} // namespace chatties

#endif // CHATTIES_AUDIO_PROCESSOR_H
