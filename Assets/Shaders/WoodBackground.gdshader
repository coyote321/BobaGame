shader_type canvas_item;

// Colors for the wood (Light and Dark Brown)
uniform vec4 wood_light : source_color = vec4(0.6, 0.4, 0.2, 1.0);
uniform vec4 wood_dark : source_color = vec4(0.35, 0.2, 0.1, 1.0);

// Controls for the grain
uniform float scale = 10.0;
uniform float turbulence = 2.0;

void fragment() {
    // Create a wave pattern based on UV coordinates
    float noise = sin(UV.y * scale * 3.0 + sin(UV.x * scale + TIME * 0.05) * turbulence);
    
    // Map the sine wave (-1 to 1) to a 0 to 1 range
    float grain = (noise + 1.0) / 2.0;
    
    // Sharpen the edges to look like wood rings
    grain = smoothstep(0.3, 0.7, grain);
    
    // Mix the two wood colors based on the grain value
    COLOR = mix(wood_dark, wood_light, grain);
}
