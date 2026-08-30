cmake_minimum_required(VERSION 3.0...3.25)
project(
    CloudRendering
    VERSION 0.1.0
    LANGUAGES CXX C 
)

if (NOT EMSCRIPTEN)
    add_subdirectory(glfw)
else()
    add_library(glfw INTERFACE)
    target_link_options(glfw INTERFACE -sUSE_GLFW=3)
endif()

add_subdirectory(webgpu)
add_subdirectory(glfw3webgpu)

add_executable(App
	src/Main.cpp
	src/webgpu-utils.h
	src/webgpu-utils.cpp

    src/FileManagement.h
    src/FileManagement.cpp
    src/Camera.h
    src/Camera.cpp
    src/VertexAttr.h
)

target_link_libraries(App PRIVATE webgpu glfw glfw3webgpu)

target_include_directories(App PRIVATE .)

target_copy_webgpu_binaries(App)

set_target_properties(App PROPERTIES
    CXX_STANDARD 17 
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
    COMPILE_WARNING_AS_ERROR ON
)

# Enable the use of emscripten_sleep()
target_link_options(App PRIVATE -sASYNCIFY)


