#include "PluginEditor.h"

GainEditor::GainEditor (GainProcessor& p)
    : AudioProcessorEditor (&p), attachment (p.apvts, "gain", slider)
{
    slider.setTextValueSuffix (" dB");
    addAndMakeVisible (slider);
    setResizable (true, true);
    setResizeLimits (200, 160, 800, 640);
    setSize (320, 240);
}

void GainEditor::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff202428));
    g.setColour (juce::Colours::white);
    g.setFont (juce::FontOptions (16.0f));
    g.drawText ("Gain Example", getLocalBounds().removeFromTop (36), juce::Justification::centred);
}

void GainEditor::resized()
{
    slider.setBounds (getLocalBounds().reduced (24).withTrimmedTop (30));
}
