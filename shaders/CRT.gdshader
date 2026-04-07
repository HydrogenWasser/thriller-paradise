shader_type canvas_item;

// ==================== CRT 复古显示器效果着色器 ====================
// 功能: 扫描线、色散(Chromatic Aberration)、屏幕弯曲、噪点

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_count : hint_range(0.0, 4096.0) = 720.0;
uniform float curvature : hint_range(0.0, 0.1) = 0.02;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float chromatic_aberration : hint_range(0.0, 5.0) = 0.8;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.05;
uniform float shake_intensity : hint_range(0.0, 0.1) = 0.0;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.02;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// 随机数生成
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// 曲线变形
vec2 curve_uv(vec2 uv) {
    vec2 centered = uv - 0.5;
    float dist = dot(centered, centered);
    vec2 curved = centered * (1.0 + curvature * dist) + 0.5;
    return curved;
}

// Vignette效果
float vignette(vec2 uv) {
    vec2 centered = uv - 0.5;
    float dist = length(centered);
    return 1.0 - smoothstep(0.4, 0.8, dist * (1.0 + vignette_intensity));
}

void fragment() {
    vec2 uv = UV;
    
    // 添加屏幕抖动
    float shake_x = (random(vec2(TIME, 0.0)) - 0.5) * shake_intensity;
    float shake_y = (random(vec2(0.0, TIME)) - 0.5) * shake_intensity;
    uv += vec2(shake_x, shake_y);
    
    // 应用曲线变形
    vec2 curved_uv = curve_uv(uv);
    
    // 采样屏幕纹理
    vec3 color;
    
    // 边界检查
    if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    // 色散效果 (Chromatic Aberration)
    float aberration = chromatic_aberration / 1000.0;
    vec2 direction = normalize(curved_uv - 0.5);
    
    float r = texture(screen_texture, curved_uv + direction * aberration).r;
    float g = texture(screen_texture, curved_uv).g;
    float b = texture(screen_texture, curved_uv - direction * aberration).b;
    
    color = vec3(r, g, b);
    
    // 扫描线效果
    float scanline = sin(curved_uv.y * scanline_count * PI) * 0.5 + 0.5;
    scanline = 1.0 - (scanline * scanline_intensity);
    color *= scanline;
    
    // 添加扫描线间隔的微弱暗线
    float scanline_dark = step(0.98, fract(curved_uv.y * scanline_count * 0.5));
    color *= (1.0 - scanline_dark * 0.3);
    
    // Vignette效果
    float vig = vignette(curved_uv);
    color *= vig;
    
    // 添加噪点
    float noise = random(curved_uv * TIME) * noise_intensity;
    color += noise;
    
    // 屏幕闪烁
    float flicker = 1.0 + (random(vec2(TIME * 10.0, 0.0)) - 0.5) * flicker_intensity;
    color *= flicker;
    
    // 绿色色调微调（复古显示器效果）
    color.g *= 1.05;
    color.b *= 0.95;
    
    COLOR = vec4(color, 1.0);
}
