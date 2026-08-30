#pragma once
#include <vector>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>

#include <webgpu/webgpu.hpp>
#include "VertexAttr.h"

class FileManagement
{
public:

    static wgpu::ShaderModule loadShaderModule(
        const std::filesystem::path& filepath,
        wgpu::Device device
    );
private:

};

