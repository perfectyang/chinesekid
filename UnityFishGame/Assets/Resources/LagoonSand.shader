Shader "Chinsekid/LagoonSand"
{
    Properties { _MainTex ("Sand detail", 2D) = "white" {} }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            sampler2D _MainTex; float4 _MainTex_ST;
            struct v2f { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; float2 world:TEXCOORD1; UNITY_FOG_COORDS(2) };
            v2f vert(appdata_base v) { v2f o; o.pos=UnityObjectToClipPos(v.vertex); o.uv=TRANSFORM_TEX(v.texcoord,_MainTex); o.world=mul(unity_ObjectToWorld,v.vertex).xz; UNITY_TRANSFER_FOG(o,o.pos); return o; }
            fixed4 frag(v2f i):SV_Target
            {
                float grain=dot(tex2D(_MainTex,i.uv).rgb,float3(.299,.587,.114))-.5;
                float broad=sin(i.world.x*.12+sin(i.world.y*.09)*1.5)*cos(i.world.y*.10-i.world.x*.035);
                float reef=smoothstep(.12,.72,broad);
                float ripples=.5+.5*sin(i.world.y*.30+i.world.x*.12+sin(i.world.x*.18));
                float3 sand=lerp(float3(.15,.42,.53),float3(.25,.55,.60),ripples*.58);
                float3 deepReef=lerp(float3(.065,.20,.34),float3(.10,.30,.43),ripples*.35);
                float3 color=lerp(sand,deepReef,reef*.76)+grain*.045;
                color+=float3(.02,.045,.06)*pow(saturate(1-abs(broad-.12)*2.2),3);
                fixed4 colorOut=fixed4(color,1);
                UNITY_APPLY_FOG(i.fogCoord,colorOut); return colorOut;
            }
            ENDCG
        }
    }
}
