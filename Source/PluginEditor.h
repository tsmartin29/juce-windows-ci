#pragma once
#include "PluginProcessor.h"

class GainEditor : public juce::AudioProcessorEditor
{
public:
    explicit GainEditor (GainProcessor&);
    void paint (juce::Graphics&) override;
    void resized() override;

private:
    juce::Slider slider { juce::Slider::RotaryHorizontalVerticalDrag, juce::Slider::TextBoxBelow };
    juce::AudioProcessorValueTreeState::SliderAttachment attachment;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (GainEditor)
};
