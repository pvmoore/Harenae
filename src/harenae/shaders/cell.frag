#version 460 core
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable
#extension GL_GOOGLE_include_directive : require

layout(location = 0) in vec2 inUV;

layout(location = 0) out vec4 outColor;

//////////////////////////////////////////////////////////////////////////////////
// Descriptor bindings
//////////////////////////////////////////////////////////////////////////////////
layout(set = 0, binding = 0, std140) uniform UBO1 {
    mat4 model;
    mat4 viewProj;
} ubo;

layout(set = 0, binding = 1, std140) uniform UBO2 {
    uvec2 worldSize;
    vec2 worldOffset;
    vec2 scale;
} scene;


// Cell bytes packed into a uint array
layout(set = 0, binding = 2, std430) readonly buffer I0 {
	uint cellData[];
};

layout(set = 0, binding = 3, std430) readonly buffer I1 {
	vec4 cellColours[];
};
//////////////////////////////////////////////////////////////////////////////////

//#define GETCELLDATA(byteIndex) (((cellData[(byteIndex) >> 2]) >> (((byteIndex) & 3u) << 3)) & 0xffu)

void main() {
    vec2 size = vec2(1000, 1000) * scene.scale;

    ivec2 pos = ivec2(scene.worldOffset + inUV*size);

    vec4 colour = vec4(0.2, 0.2, 0.2, 1);

    if(pos.x >= 0 && pos.x < scene.worldSize.x && pos.y >= 0 && pos.y < scene.worldSize.y) {
        //uint type = GETCELLDATA(pos.x + pos.y*ubo.windowSize.x);
        uint cell = cellData[pos.x + pos.y*scene.worldSize.x];
        uint type = cell & 0xff; 

        colour = cellColours[type];
    }

    outColor = colour;
}