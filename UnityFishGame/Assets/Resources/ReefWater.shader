Shader "Chinsekid/ReefWater"
{
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            struct appdata { float4 vertex:POSITION; };
            struct v2f { float4 pos:SV_POSITION; float2 world:TEXCOORD0; UNITY_FOG_COORDS(1) };
            v2f vert(appdata v){v2f o;o.pos=UnityObjectToClipPos(v.vertex);o.world=mul(unity_ObjectToWorld,v.vertex).xz;UNITY_TRANSFER_FOG(o,o.pos);return o;}
            fixed4 frag(v2f i):SV_Target
            {
                float2 p=i.world*.80;
                float t=_Time.y*.23;
                float a=sin(p.x+sin(p.y*1.17+t)*1.4+t);
                float b=sin(p.y+cos(p.x*.91-t)*1.6-t*.7);
                float caustic=pow(saturate(1-abs(a+b)*2.8),5);
                float lagoon=.5+.5*sin(i.world.x*.035+i.world.y*.06);
                float sunbeam=pow(saturate(.5+.5*cos(i.world.x*.23+i.world.y*.08+t*.16)),8);
                fixed4 color=fixed4(lerp(float3(.10,.55,.80),float3(.59,.91,1),caustic),.035+caustic*.12+lagoon*.025+sunbeam*.04);
                UNITY_APPLY_FOG(i.fogCoord,color);return color;
            }
            ENDCG
        }
    }
}
