#version 120

float maxBrighten = 10.0;   //Maximum brightening of the screen (should be greater than 1)
float HDRRatio = 1.0;       //Ajust for stronger or subtler HDR (between 0 and 1)
float idealLum = 0.5;       //The prefered average luminosity of the screen (between 0 and 1)

uniform sampler2D DiffuseSampler;
uniform sampler2D MBSampler;
uniform vec2 OutSize;
varying vec2 texCoord;
varying vec2 oneTexel;

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

vec4 lightAjust (vec4 color,float amount){
    float newLum = 1.0-pow(1.0-toLum(color),amount);
    float oldLum = toLum(color);
    vec4 color1 = color*(newLum/oldLum);

    vec4 color2 = 1.0-pow(1.0-color,vec4(amount));

    return mix(color1,color2,0.5);
}



//samples color from 16 places on the screen and averages them

vec4 averageTopLeft=(
    toLinear(texture2D(MBSampler, vec2(.2,.2)))+
    toLinear(texture2D(MBSampler, vec2(.2,.4)))+
    toLinear(texture2D(MBSampler, vec2(.4,.2)))+
    toLinear(texture2D(MBSampler, vec2(.4,.4)))
)/4.0;

vec4 averageTopRight=(
    toLinear(texture2D(MBSampler, vec2(.6,.2)))+
    toLinear(texture2D(MBSampler, vec2(.6,.4)))+
    toLinear(texture2D(MBSampler, vec2(.8,.2)))+
    toLinear(texture2D(MBSampler, vec2(.8,.4)))
)/4.0;

vec4 averageBottomLeft=(
    toLinear(texture2D(MBSampler, vec2(.2,.6)))+
    toLinear(texture2D(MBSampler, vec2(.2,.8)))+
    toLinear(texture2D(MBSampler, vec2(.4,.6)))+
    toLinear(texture2D(MBSampler, vec2(.4,.8)))
)/4.0;

vec4 averageBottomRight=(
    toLinear(texture2D(MBSampler, vec2(.6,.6)))+
    toLinear(texture2D(MBSampler, vec2(.6,.8)))+
    toLinear(texture2D(MBSampler, vec2(.8,.6)))+
    toLinear(texture2D(MBSampler, vec2(.8,.8)))
)/4.0;

float topLeftLum = toLum(averageTopLeft);
float topRightLum = toLum(averageTopRight);
float bottomLeftLum = toLum(averageBottomLeft);
float bottomRightLum = toLum(averageBottomRight);

float averageLum = mix(
     mix(topLeftLum, bottomLeftLum, texCoord.y)
    ,mix(topRightLum, bottomRightLum, texCoord.y)
    ,texCoord.x
);

void main() {
    vec4 color = toLinear( texture2D(DiffuseSampler, texCoord) );

    float maxAveragedBrighten  = ( maxBrighten - ( 1.0 - HDRRatio ) ) / HDRRatio;
    float brightenRatio        = idealLum / averageLum;
    float clampedBrightenRatio = clamp( brightenRatio, 0.5, maxAveragedBrighten );

    vec4 averagedColor = lightAjust(color,clampedBrightenRatio);
    vec4 finalColor    = mix(color,averagedColor,HDRRatio);


    gl_FragColor = toGamma( finalColor );

}

/*

    //vec4 x = max(vec4(0.0),outputColor-0.004);
    //vec4 filmicTonemap=(x*(6.2*x+0.5))/(x*(6.2*x+1.7)+0.06);

    vec4 inputHSL = RGBtoHSL(inputColor);
    

    //desaturate dark things
    float brightness = min(0.25,inputHSL.b)*4.0;
    vec4 finalHSL = inputHSL*vec4(1.0,0.5+(brightness*0.5),1.0,1.0);
    vec4 color=HSLtoRGB(finalHSL);

vec4 RGBtoHSL( vec4 col )
{
        float red   = col.r;
        float green = col.g;
        float blue  = col.b;
        float minc  = min(min( col.r, col.g),col.b) ;
        float maxc  = max(max( col.r, col.g),col.b);
        float delta = maxc - minc;
        float lum = (minc + maxc) * 0.5;
        float sat = 0.0;
        float hue = 0.0;
        if (lum > 0.0 && lum < 1.0) {
                float mul = (lum < 0.5)  ?  (lum)  :  (1.0-lum);
                sat = delta / (mul * 2.0);
        }
        vec3 masks = vec3(
                (maxc == red   && maxc != green) ? 1.0 : 0.0,
                (maxc == green && maxc != blue)  ? 1.0 : 0.0,
                (maxc == blue  && maxc != red)   ? 1.0 : 0.0
        );
        vec3 adds = vec3(
                          ((green - blue ) / delta),
                2.0 + ((blue  - red  ) / delta),
                4.0 + ((red   - green) / delta)
        );
        float deltaGtz = (delta > 0.0) ? 1.0 : 0.0;
        hue += dot( adds, masks );
        hue *= deltaGtz;
        hue /= 6.0;
        if (hue < 0.0)
                hue += 1.0;
        return vec4( hue, sat, lum, col.a );
}

vec4 HSLtoRGB( vec4 col )
{
    const float onethird = 1.0 / 3.0;
    const float twothird = 2.0 / 3.0;
    const float rcpsixth = 6.0;

    float hue = col.x;
    float sat = col.y;
    float lum = col.z;

    vec3 xt = vec3(
        rcpsixth * (hue - twothird),
        0.0,
        rcpsixth * (1.0 - hue)
    );

    if (hue < twothird) {
        xt.r = 0.0;
        xt.g = rcpsixth * (twothird - hue);
        xt.b = rcpsixth * (hue      - onethird);
    } 

    if (hue < onethird) {
        xt.r = rcpsixth * (onethird - hue);
        xt.g = rcpsixth * hue;
        xt.b = 0.0;
    }

    xt = min( xt, 1.0 );

    float sat2   =  2.0 * sat;
    float satinv =  1.0 - sat;
    float luminv =  1.0 - lum;
    float lum2m1 = (2.0 * lum) - 1.0;
    vec3  ct     = (sat2 * xt) + satinv;

    vec3 rgb;
    if (lum >= 0.5)
         rgb = (luminv * ct) + lum2m1;
    else rgb =  lum    * ct;

    return vec4( rgb, col.a );
}
*/