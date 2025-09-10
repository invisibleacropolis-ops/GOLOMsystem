shader_type canvas_item;
uniform int mode = 0;
void fragment(){
    vec4 c = texture(SCREEN_TEXTURE, SCREEN_UV);
    if(mode==1){
        float g = max(max(c.r,c.g),c.b);
        COLOR = vec4(0.0,g,0.0,c.a);
    }else if(mode==2){
        float gray = dot(c.rgb, vec3(0.299,0.587,0.114));
        COLOR = vec4(vec3(gray*0.5), c.a);
    }else if(mode==3){
        float r = c.r;
        float g2 = (c.r + c.g) * 0.5;
        COLOR = vec4(r, g2, c.b, c.a);
    }else{
        COLOR = c;
    }
}
