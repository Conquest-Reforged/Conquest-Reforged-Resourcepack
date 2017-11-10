#version 120

uniform sampler2D DiffuseSampler;
uniform sampler2D DarkBlurSampler;
uniform vec2 OutSize;
varying vec2 texCoord;

float toLum (vec4 color){
    return dot(color.rgb, vec3(.2125, .7154, .0721) );
}

vec4 toLinear (vec4 color){
    return pow(color,vec4(2.2));
}

float toLinear (float value){
    return pow(value,2.2);
}

vec4 toGamma (vec4 color){
    return pow(color,vec4(1.0/2.2));
}

float toGamma (float value){
    return pow(value,1.0/2.2);
}

vec4 toReinhard (vec4 color){
    float lum = toLum(color);
    float reinhardLum = lum/(1.0+lum);
    return color*(reinhardLum/lum);
}

vec4 toneMap (vec4 color){
    float maxColor=max(color.r,max(color.g,color.b));
    vec4 ret=color;
    if(maxColor>1.0){
        ret=mix(color/maxColor,vec4(1.0),max(maxColor-1.0,0.0)*0.333  );
    };
    return (ret*0.1)+(color*0.9);
}

void main() {
    vec4 color = texture2D(DiffuseSampler, texCoord);
    vec4 bloom = texture2D(DarkBlurSampler, texCoord);

    vec4 bloomedRaw = color + bloom;

    vec4 bloomed = toLinear(bloomedRaw);

    vec4 toneMapped = bloomed;//toneMap(bloomed);

    vec4 final = mix(clamp(toneMapped,0.0,1.0),toLinear(color),0.3);

    gl_FragColor = toGamma(final);

}
