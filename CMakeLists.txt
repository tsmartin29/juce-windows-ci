cmake_minimum_required(VERSION 3.22)
project(GainExample VERSION 0.1.0 LANGUAGES C CXX)

# A tiny JUCE gain plug-in that exists to give the Windows CI something real to build, test and package.
# Replace Source/ and the target names with your own plug-in; the workflow only needs the names below.

set(CMAKE_CXX_STANDARD 20)               # MSVC and clang both accept C++20; avoids GNU-only tricks
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "")

# JUCE is NOT included in this repo. CMake fetches it at configure time from the official repository.
# JUCE is dual-licensed (AGPLv3 or a commercial JUCE licence): you are responsible for having a licence
# that fits what you ship. See README.md, "JUCE licence".
set(JUCE_GIT_TAG "9.0.3" CACHE STRING "JUCE tag (or commit) to build against")
option(GAIN_STANDALONE "Also build the Standalone app" OFF)

include(FetchContent)
FetchContent_Declare(JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG        ${JUCE_GIT_TAG}
    GIT_SHALLOW    ON)
# To use a JUCE checkout you already have (CI does this, with a cache):
#   cmake -DFETCHCONTENT_SOURCE_DIR_JUCE=/path/to/JUCE ...
FetchContent_MakeAvailable(JUCE)

# Optional: ONNX Runtime, if the workflow fetched it (-DORT_ROOT=<folder with include/ and lib/>).
# The example plug-in does not use it; this only shows where you would hook it in.
if(ORT_ROOT)
    message(STATUS "ONNX Runtime found at ${ORT_ROOT}")
endif()

# Shared code: compiled into both the plug-in and the test (the JUCE modules are compiled into each target).
add_library(SharedCode INTERFACE)
target_sources(SharedCode INTERFACE
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h)
target_include_directories(SharedCode INTERFACE Source)
target_compile_definitions(SharedCode INTERFACE
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0)
target_link_libraries(SharedCode INTERFACE
    juce::juce_audio_utils
    juce::juce_gui_basics
    juce::juce_recommended_config_flags
    juce::juce_recommended_lto_flags
    juce::juce_recommended_warning_flags)

set(FORMATS VST3)
if(GAIN_STANDALONE)
    list(APPEND FORMATS Standalone)
endif()

juce_add_plugin(GainExample
    COMPANY_NAME "Example Audio"
    PRODUCT_NAME "GainExample"
    BUNDLE_ID "com.example.gainexample"          # placeholder: use your own reverse-DNS id
    PLUGIN_MANUFACTURER_CODE Exmp
    PLUGIN_CODE Gnex
    FORMATS ${FORMATS}
    VST3_CATEGORIES Fx
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT FALSE
    COPY_PLUGIN_AFTER_BUILD FALSE)
target_link_libraries(GainExample PRIVATE SharedCode)

# Headless unit test: DSP, state, editor render. A plain console exe that the workflow runs on the runner.
juce_add_console_app(GainExampleTest PRODUCT_NAME "GainExampleTest")
target_sources(GainExampleTest PRIVATE Test/unit_test.cpp)
target_link_libraries(GainExampleTest PRIVATE SharedCode)
