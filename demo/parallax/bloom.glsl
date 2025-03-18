// Moderate wave distortion shader with subtle color effects

uniform float intensity = 1.0;   // Effect intensity (controlled from Lua)
uniform float time = 0.0;        // Time for animation

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Create a distorted texture coordinate with a sine wave
    vec2 distortedCoords = texture_coords;

    // Apply gentle wave distortion
    distortedCoords.x += sin(distortedCoords.y * 8.0 + time) * 0.02 * intensity;
    distortedCoords.y += cos(distortedCoords.x * 8.0 + time * 0.5) * 0.02 * intensity;

    // Get the pixel color from the distorted position
    vec4 originalColor = Texel(texture, distortedCoords);

    // Create more subtle, bluish color cycling
    vec3 tint = vec3(
        0.5 + 0.2 * sin(time * 0.5),
        0.6 + 0.2 * sin(time * 0.5 + 1.0),
        0.7 + 0.3 * sin(time * 0.5 + 2.0)
    );

    // Apply a gentler color tint
    vec4 result = originalColor;
    result.rgb = mix(result.rgb, tint, 0.15 * intensity);

    // Add a subtle pulsing brightness
    float pulse = 0.5 + 0.5 * sin(time * 0.7);
    result.rgb += pulse * 0.1 * intensity;

    // Preserve alpha
    result.a = originalColor.a;

    return result;
}
