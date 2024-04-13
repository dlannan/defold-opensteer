varying highp vec4 var_position;
varying mediump vec3 var_normal;
varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;
uniform lowp vec4 uvscale;

void main()
{
    // Pre-multiply alpha since all runtime textures already are
    vec4 color = texture2D(tex0, var_texcoord0.xy * vec2(uvscale.x, uvscale.y));

    // Diffuse light calculations
    gl_FragColor = vec4(color.rgba);
}

