Shader "Custom/Snow"
{
    Properties
    {
        [Header(Fresh Snow)]
        _FreshColor("Fresh Color", Color) = (1,1,1,1)
        _FreshAlbedoTex("Fresh Albedo", 2D) = "white" {}
        _FreshRoughnessTex("Fresh Roughness", 2D) = "gray" {}
        _FreshNormalTex("Fresh Normals", 2D) = "bump" {}
        _FreshOcclusionTex("Fresh Occlusion", 2D) = "white" {}

        [Header(Trampled Snow)]
        _TrampledColor("Trampled Color", Color) = (1,1,1,1)
        _TrampledAlbedoTex("Trampled Albedo", 2D) = "white" {}
        _TrampledRoughnessTex("Trampled Roughness", 2D) = "gray" {}
        _TrampledNormalTex("Trampled Normals", 2D) = "bump" {}
        _TrampledOcclusionTex("Trampled Occlusion", 2D) = "white" {}

        [Header(Other)]
        _Tessellation("Tessellation", Range(1, 32)) = 16
        _DisplacementTex("Displacement", 2D) = "white" {}
        _DisplacementAmount("Displacement Amount", Range(0, 1)) = 0.3
        _UvToWorldRatio("Texture UV over world XZ", Vector) = (0.2, 0.2, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM

        #pragma surface surf Standard addshadow fullforwardshadows vertex:vert tessellate:tessDistance nolightmap
        #pragma target 4.6
        #pragma enable_d3d11_debug_symbols

        #include "Tessellation.cginc"

        struct appdata
        {
            float4 vertex : POSITION;
            float4 tangent : TANGENT;
            float3 normal : NORMAL;
            float2 texcoord : TEXCOORD0;
        };

        sampler2D _DisplacementTex;
        float4 _DisplacementTex_TexelSize;
        float _DisplacementAmount;
        float _Tessellation;
        float2 _UvToWorldRatio;

        float2 getDisplacementUV(float2 uv)
        {
            return float2(1-uv.x, uv.y);
        }

        float4 tessDistance(appdata v0, appdata v1, appdata v2)
        {
            float minDist = 10.0;
            float maxDist = 25.0;
            return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, minDist, maxDist, _Tessellation);
        }

        float getDisplacement(float2 uv)
        {
            return (1.0f - tex2Dlod(_DisplacementTex, float4(getDisplacementUV(uv),0,0)).r) * _DisplacementAmount;
        }

        float3 calculateDisplacementNormal(float2 uv)
        {
            float4 h;
            h[0] = getDisplacement(uv + _DisplacementTex_TexelSize.xy * float2( 0, -1));
            h[1] = getDisplacement(uv + _DisplacementTex_TexelSize.xy * float2(-1,  0));
            h[2] = getDisplacement(uv + _DisplacementTex_TexelSize.xy * float2( 1,  0));
            h[3] = getDisplacement(uv + _DisplacementTex_TexelSize.xy * float2( 0,  1));

            float3 n;
            n.z = h[3] - h[0];
            n.x = h[2] - h[1];
            n.y = 2;

            n.xz *= _DisplacementTex_TexelSize.zw * _UvToWorldRatio;

            return normalize(n);
        }

        void vert(inout appdata v)
        {
            v.vertex.y += getDisplacement(v.texcoord);
            v.normal = calculateDisplacementNormal(v.texcoord);
        }

        float4 _FreshColor;
        sampler2D _FreshAlbedoTex;
        sampler2D _FreshRoughnessTex;
        sampler2D _FreshNormalTex;
        sampler2D _FreshOcclusionTex;
        float4 _TrampledColor;
        sampler2D _TrampledAlbedoTex;
        sampler2D _TrampledRoughnessTex;
        sampler2D _TrampledNormalTex;
        sampler2D _TrampledOcclusionTex;

        struct Input
        {
            float2 uv_FreshAlbedoTex;
            float3 worldNormal; INTERNAL_DATA
        };

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float2 uv = IN.uv_FreshAlbedoTex;

            float trampledness = tex2D(_DisplacementTex, getDisplacementUV(uv));

            float3 freshAlbedo = tex2D(_FreshAlbedoTex, uv).rgb * _FreshColor;
            float3 trampledAlbedo = tex2D(_TrampledAlbedoTex, uv).rgb * _TrampledColor;
            float3 albedo = lerp(freshAlbedo, trampledAlbedo, trampledness);
            o.Albedo = albedo;

            float4 freshNormalsSample = tex2D(_FreshNormalTex, uv);
            float4 trampledNormalsSample = tex2D(_TrampledNormalTex, uv);
            o.Normal = UnpackNormal(lerp(freshNormalsSample, trampledNormalsSample, trampledness));

            float freshRoughness = tex2D(_FreshRoughnessTex, uv).r;
            float trampledRoughness = tex2D(_TrampledRoughnessTex, uv).r;
            o.Smoothness = 1.0f - lerp(freshRoughness, trampledRoughness, trampledness);

            float freshOcclusion = tex2D(_FreshOcclusionTex, uv).r;
            float trampledOcclusion = tex2D(_TrampledOcclusionTex, uv).r;
            o.Occlusion = lerp(freshOcclusion, trampledOcclusion, trampledness);

            o.Emission = 0;
            o.Metallic = 0;
            o.Alpha = 1;

            // debug
            //o.Albedo = 0.5;
            //o.Albedo = tex2D(_DisplacementTex, getDisplacementUV(uv)).r;
            //o.Occlusion = 1;
            //o.Smoothness = 0.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
