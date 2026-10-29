Shader "Chinsekid/ReefSurface"
{
    Properties
    {
        _BaseColor ("Root color", Color) = (0.6,0.2,0.7,1)
        _TopColor ("Tip color", Color) = (1,0.5,0.8,1)
        _Sway ("Plant sway", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull Off
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            fixed4 _BaseColor, _TopColor;
            float _Sway;
            struct appdata { float4 vertex:POSITION; float3 normal:NORMAL; float2 uv:TEXCOORD0; };
            struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float height:TEXCOORD1; float3 normal:TEXCOORD2; UNITY_FOG_COORDS(3) };
            v2f vert(appdata v)
            {
                v2f o;
                float3 world=mul(unity_ObjectToWorld,v.vertex).xyz;
                float bend=saturate(v.vertex.y*.6);
                v.vertex.x += sin(_Time.y*1.15+world.z*.65+world.x*.35)*bend*bend*.15*_Sway;
                v.vertex.z += cos(_Time.y*.85+world.x*.5)*bend*bend*.09*_Sway;
                o.pos=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.height=saturate(v.vertex.y*.65);
                o.normal=UnityObjectToWorldNormal(v.normal);UNITY_TRANSFER_FOG(o,o.pos);return o;
            }
            fixed4 frag(v2f i, fixed facing:VFACE):SV_Target
            {
                float3 normal=normalize(i.normal)*(facing>0?1:-1);
                float diffuse=saturate(dot(normal,normalize(_WorldSpaceLightPos0.xyz)));
                float3 light=.65+_LightColor0.rgb*diffuse*.30;
                float ribs=.985+.015*cos(i.uv.x*65);
                fixed4 color=fixed4(lerp(_BaseColor.rgb,_TopColor.rgb,i.height)*light*ribs,1);
                UNITY_APPLY_FOG(i.fogCoord,color);return color;
            }
            ENDCG
        }
    }
}
