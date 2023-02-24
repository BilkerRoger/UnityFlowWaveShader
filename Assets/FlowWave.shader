Shader "CC/FlowWave"
{
    Properties
    {
        [PerRendererData] _MainTex("Sprite Texture", 2D) = "white" {}
        _Color("Tint", Color) = (1,1,1,1)

        _Amplitude("Amplitude", Float) = 0.001
        _Waves("Waves", Float) = 5.0

		_Value ("Value", Float) = 0.01
		_Contrast ("_Contrast", Float) = 10
		_LightColor ("_LightColor", Color) = (1,1,0,1)

        _Flush ("Flush", 2D) = "white" {}
        _Speed ("Speed", Float) = 0.5
        _Inter ("Interval", Float) = 1.5
        _Rotate ("Rotate", Float) = 0

        _StencilComp("Stencil Comparison", Float) = 8
        _Stencil("Stencil ID", Float) = 0
        _StencilOp("Stencil Operation", Float) = 0
        _StencilWriteMask("Stencil Write Mask", Float) = 255
        _StencilReadMask("Stencil Read Mask", Float) = 255

        _ColorMask("Color Mask", Float) = 15

        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip("Use Alpha Clip", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }

        Stencil
        {
            Ref[_Stencil]
            Comp[_StencilComp]
            Pass[_StencilOp]
            ReadMask[_StencilReadMask]
            WriteMask[_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest[unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask[_ColorMask]

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            #pragma multi_compile __ UNITY_UI_ALPHACLIP

            struct appdata_t
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                fixed4 color : COLOR;
                half2 texcoord : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
            };

            sampler2D _MainTex;
            fixed4 _Color;
            fixed4 _TextureSampleAdd;
            float4 _ClipRect;

            float _Amplitude;
            float _Waves;

            float _Value;
			float _Contrast;
			half4 _LightColor;

            sampler2D _Flush;
            float _Speed;
            float _Inter;
            float _Rotate;

            inline float2 Wave(float2 uv)
            {
                return float2(uv.x, uv.y + sin(uv.x * _Waves + _Time.w) * _Amplitude);
            }

            inline float SmoothedClip(float2 position, float4 clipRect)
            {
                float2 inside = saturate((position.xy - clipRect.xy) * 500) * saturate((clipRect.zw - position.xy) * 200);
                return inside.x * inside.y;
            }

            v2f vert(appdata_t IN)
            {
                v2f OUT;
                OUT.worldPosition = IN.vertex;
                OUT.vertex = UnityObjectToClipPos(IN.vertex);

                OUT.texcoord = IN.texcoord;

            #ifdef UNITY_HALF_TEXEL_OFFSET
                OUT.vertex.xy += (_ScreenParams.zw - 1.0) * float2(-1, 1);
            #endif

                OUT.color = IN.color * _Color;
                return OUT;
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                float2 uv = Wave(IN.texcoord);
                half4 tex = tex2D(_MainTex, uv);
                tex.a *= SmoothedClip(uv, float4(0, 0, 1, 1));
                half4 color = (tex + _TextureSampleAdd) * IN.color;

                color.a *= UnityGet2DClipping(IN.worldPosition.xy, _ClipRect);

            #ifdef UNITY_UI_ALPHACLIP
                clip(color.a - 0.001);
            #endif

				fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
				half3 wbColor = lerp(avgColor, color.rgb, _Contrast);
				half w = wbColor.r * wbColor.g * wbColor.b;

                uv = IN.texcoord;

                //角度控制
                float angle = _Rotate * 0.017453292519943295;
                uv -= float2(0.5,0.5);
                uv = float2(uv.x*cos(angle)-uv.y*sin(angle),uv.y*cos(angle) + uv.x*sin(angle));
                uv += float2(0.5,0.5);

				uv.y *= uv.x;
				
                //速度控制
                float y = uv.y - _Time.y * _Speed;
                //间隔控制
                _Inter = max(1, _Inter);
                uv.y =  y - floor(y / _Inter) * _Inter;

                half4 flush = tex2D(_Flush, uv);

                color.rgb += _LightColor.rgb * w * flush.a * _Value;

                return color;
            }

            ENDCG
        }
    }
}
