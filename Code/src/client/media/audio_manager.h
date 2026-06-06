#ifndef CHATTIES_AUDIO_MANAGER_H
#define CHATTIES_AUDIO_MANAGER_H

#include <portaudio.h>
#include <vector>
#include <memory>
#include <cstdint>

namespace chatties {
namespace client {

class AudioManager {
public:
    AudioManager();
    ~AudioManager();
    
    bool initialize();
    void shutdown();
    
    bool start_microphone();
    bool stop_microphone();
    
    bool start_speaker();
    bool stop_speaker();
    
    std::vector<float> get_microphone_data();
    void play_audio(const std::vector<float>& data);
    
private:
    PaStream* input_stream_;
    PaStream* output_stream_;
    bool initialized_;
};

} // namespace client
} // namespace chatties

#endif // CHATTIES_AUDIO_MANAGER_H
