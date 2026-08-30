#include "FileManagement.h"



wgpu::ShaderModule FileManagement::loadShaderModule(const std::filesystem::path& filepath,
                                                    wgpu::Device device) {

    std::ifstream file(filepath);
    if (!file.is_open()) {
        return nullptr;
    }
    file.seekg(0, std::ios::end);
    size_t size = file.tellg();
    std::string shaderSource(size, ' ');
    file.seekg(0);
    file.read(shaderSource.data(), size);


    // create shader module
    wgpu::ShaderModuleDescriptor shaderDesc; // main description
    wgpu::ShaderModuleWGSLDescriptor shaderCodeDesc; // additional, chained description for WGSL
    shaderCodeDesc.chain.next = nullptr;
    shaderCodeDesc.chain.sType = wgpu::SType::ShaderModuleWGSLDescriptor; // set to WGSL

    shaderDesc.nextInChain = &shaderCodeDesc.chain; // connect additional to main via CHAIN
    shaderCodeDesc.code = shaderSource.c_str();
    return device.createShaderModule(shaderDesc);
}

