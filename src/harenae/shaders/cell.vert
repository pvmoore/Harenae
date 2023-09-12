#version 460 core
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable
#extension GL_GOOGLE_include_directive : require

// input
layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec2 inUV;

// output
layout(location = 0) out vec2 fragUV;

//////////////////////////////////////////////////////////////////////////////////
// Descriptor bindings
//////////////////////////////////////////////////////////////////////////////////
layout(set = 0, binding = 0, std140) uniform UBO1 {
    mat4 model;
    mat4 viewProj;
    uvec2 worldOffset;
    uvec2 windowSize;
} ubo;
//////////////////////////////////////////////////////////////////////////////////

void main() {
    mat4 trans = ubo.viewProj * ubo.model;

    gl_Position = trans * vec4(inPosition, 0, 1);
    fragUV      = inUV;
}