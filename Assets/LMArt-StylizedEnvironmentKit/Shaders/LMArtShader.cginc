//--------------------------------------------
//Stylized Environment Kit
//LittleMarsh CG ART
//version 1.5.0
//--------------------------------------------

#ifndef LMArtShader_INCLUDED
#define LMArtShader_INCLUDED

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

/////////////Common//////////////////////////

sampler2D _AlbedoTex, _SpecularTex, _TransTex, _NormalMap;

fixed _CutOff, _TransArea, _NormalScale, _Shininess, _SpecularPower, _ShadowIntensity, _TransPower;
half _AnimationScale;
fixed3 _TransColor, _SpecularColor;
float _UseAnimation, _UseSpecular, _UseNormal;

sampler2D _TopTex, _MidTex, _BtmTex, _TopBumpMap, _MidBumpMap, _BtmBumpMap, _TopReflectMap, _MidReflectMap, _BtmReflectMap;

fixed _TopBumpScale, _MidBumpScale, _BtmBumpScale, _BlendFactor, _TopUVScale, _MidUVScale, _BtmUVScale, _TopReflectScale, _MidReflectScale, _BtmReflectScale;
float4 _TopTex_ST, _MidTex_ST, _BtmTex_ST;
float _TopWorldUV, _MidWorldUV, _BtmWorldUV, _UseReflection;
fixed3 _ReflectionColor;

float _SAWorldUV;
fixed _SAUVScale, _SABumpScale, _ReflectionIntensity;

sampler2D _SABumpMap, _ReflectionMask;


inline float3x3 tspace(half3 worldNormal, float3 normal, float4 tangent)
{
	half3 worldTangent = UnityObjectToWorldDir(tangent.xyz);
	half tangentSign = tangent.w * unity_WorldTransformParams.w;
	half3 wBitangent = cross(worldNormal, worldTangent) * tangentSign;

	float3x3 tspaceC;
	tspaceC[0] = half3(worldTangent.x, wBitangent.x, worldNormal.x);
	tspaceC[1] = half3(worldTangent.y, wBitangent.y, worldNormal.y);
	tspaceC[2] = half3(worldTangent.z, wBitangent.z, worldNormal.z);

	return tspaceC;
}

inline half3 worldNormal(float3 tspace0, float3 tspace1, float3 tspace2, half3 tNormal)
{
	half3 wNormal;
	wNormal.x = dot(tspace0, tNormal);
	wNormal.y = dot(tspace1, tNormal);
	wNormal.z = dot(tspace2, tNormal);
	wNormal = normalize(wNormal);

	return wNormal;
}

float rand(float2 st)
{
	return frac(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453);
}

inline half3 computeSpecular(half3 lightDir, half3 wNormal, half3 viewDir, fixed4 specularTex, fixed lightCal)
{
	half3 R = reflect(-lightDir, wNormal);
	half specularReflection = clamp(dot(viewDir, R), 0.0, 1.0);
	half3 specular = pow(specularReflection, _Shininess) * _SpecularPower * specularTex.rgb * _LightColor0.rgb * _SpecularColor.rgb;
	specular = lerp(fixed3(0, 0, 0), specular, lightCal * specularTex.a);

	return specular;
}

inline half3 worldReflect(float3 worldPos, half3 wNormal, half3 lightDir)
{
	half3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
	half3 worldRefl = reflect(-worldViewDir, wNormal);
	half4 reflData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl);
	half3 reflHDR = DecodeHDR(reflData, unity_SpecCube0_HDR);

	half3 reflection = reflHDR * _ReflectionColor;

	return reflection;
}

inline half computeShadowmask(half lightmask, half2 uv, float3 worldPos, fixed shadow)
{
		lightmask = UnitySampleBakedOcclusion(uv, worldPos);

	#if defined(HANDLE_SHADOWS_BLENDING_IN_GI)
		float zDist = dot(_WorldSpaceCameraPos - worldPos, UNITY_MATRIX_V[2].xyz);
		float fadeDist = UnityComputeShadowFadeDistance(worldPos, zDist);
		lightmask = UnityMixRealtimeAndBakedShadows(shadow, lightmask, UnityComputeShadowFade(fadeDist));
	#endif

	return lightmask;
}

inline half3 computeLightmap(half3 lightmap, half2 uv2, half3 wNormal)
{
	half4 bakedTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, uv2);
	half3 bakedColor = DecodeLightmap(bakedTex);

	#ifdef DIRLIGHTMAP_COMBINED
		half4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, uv2);
		lightmap += DecodeDirectionalLightmap(bakedColor, bakedDirTex, wNormal);
	#else
		lightmap += bakedColor;
	#endif

	return lightmap;
}

inline half3 computeDynamicLightmap(half3 lightmap, half uv3, half3 wNormal)
{
	half3 realLightmap = DecodeRealtimeLightmap(UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, uv3));

	#ifdef DIRLIGHTMAP_COMBINED
		half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, uv3);
		lightmap += DecodeDirectionalLightmap(realLightmap, realtimeDirTex, wNormal);
	#else
		lightmap += realLightmap;
	#endif

	return lightmap;
}



/////////////Nature Leaves//////////////////////////

struct appdata_lf
{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 texcoord : TEXCOORD0;
	fixed4 color : COLOR;
	float4 tangent : TANGENT;

	#ifdef LIGHTMAP_ON
		half4 texcoord1 : TEXCOORD1;
	#endif
	#ifdef DYNAMICLIGHTMAP_ON
		half4 texcoord2 : TEXCOORD2;
	#endif

	UNITY_VERTEX_INPUT_INSTANCE_ID//VR
};

inline float3 vertexAnimation(float3 worldPos, float4 vertex, fixed4 color)
{
	float t1 = _Time.y + (worldPos.x * 0.6) - (worldPos.y * 0.6) - (worldPos.z * 0.8);
	float t2 = _Time.y + (worldPos.x * 2) + (worldPos.z * 3);

	float randNoise = rand(float2((worldPos.x * 0.8), (worldPos.z * 0.8)));

	float x = 1.44* pow(cos(t1 / 2), 2) + sin(t1 / 2)* randNoise;
	float y = (2 * sin(3 * x) + sin(10 * x) - cos(5 * x)) / 10 * randNoise;

	float3 move = float3(0, 0, 0);
	move.x = lerp(0, y, color.r) / 2 * _AnimationScale;
	move.y = lerp(0, y, color.r) / 4 * _AnimationScale;
	move.z = lerp(0, sin(t2) * cos(2 * t2) * _AnimationScale / 10, color.r);

	return move;
}

inline half3 worldNormalLF(float3 tspace0, float3 tspace1, float3 tspace2, half3 tNormal, fixed facing)
{
	half3 wNormal;
	wNormal.x = dot(tspace0, tNormal);
	wNormal.y = dot(tspace1, tNormal);
	wNormal.z = dot(tspace2, tNormal);
	wNormal = lerp(-wNormal, wNormal, step(0, facing));
	wNormal = normalize(wNormal);

	return wNormal;
}

inline fixed4 computeLFCol(fixed4 col, half3 ambient, half3 lightDir, half3 wNormal, fixed lightCal,
	fixed specular, fixed4 transTex)
{
	half3 nl = max(0, dot(wNormal, lightDir));
	half3 nlr = max(0, dot(-wNormal, lightDir));
	nlr = smoothstep(_TransArea, 1, nlr);

	half3 diffuse = nl * _LightColor0.rgb * lightCal + ambient;
	half3 trans = lerp(fixed3(0, 0, 0), _LightColor0.rgb * transTex * _TransColor.rgb, nlr * lightCal);
	half3 Translucency = _TransPower * _LightColor0.rgb * transTex * _TransColor.rgb
		* pow(max(0.0, dot(lightDir, -wNormal)), _TransArea);
	Translucency = lerp(fixed3(0, 0, 0), Translucency, lightCal);

	col.rgb *= diffuse;
	col.rgb += specular;
	col.rgb += trans;
	col.rgb += Translucency;

	return col;
}

inline fixed3 lightmapLFCol(fixed3 col, half3 lightDir, half3 wNormal, fixed lightCal,
	fixed specular, fixed4 transTex, fixed3 lightmap, half lightmask)
{	
	half3 nl = max(0, dot(wNormal, lightDir));
	half3 nlr = max(0, dot(-wNormal, lightDir));
	nlr = smoothstep(_TransArea, 1, nlr);

	half3 diffuse = nl * _LightColor0.rgb * lightmask * lightCal + lightmap;
	half3 trans = lerp(fixed3(0, 0, 0), _LightColor0.rgb * transTex * _TransColor.rgb, nlr * lightCal);
	half3 Translucency = _TransPower * _LightColor0.rgb * transTex * _TransColor.rgb
		* pow(max(0.0, dot(lightDir, -wNormal)), _TransArea);
	Translucency = lerp(fixed3(0, 0, 0), Translucency, lightCal);

	col.rgb *= diffuse;
	col.rgb += specular;
	col.rgb += trans;
	col.rgb += Translucency;

	return col;
}


struct appdata_shd
{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 texcoord : TEXCOORD0;
	fixed4 color : COLOR;

	UNITY_VERTEX_INPUT_INSTANCE_ID//VR
};


/////////////VertexBlending//////////////////////////



struct appdata_VB
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float3 normal : NORMAL;
	fixed4 color : COLOR;
	float4 tangent : TANGENT;

	#ifdef LIGHTMAP_ON
		half4 texcoord1 : TEXCOORD1;
	#endif
	#ifdef DYNAMICLIGHTMAP_ON
		half4 texcoord2 : TEXCOORD2;
	#endif

	UNITY_VERTEX_INPUT_INSTANCE_ID//VR
};

inline half2 maskBlending(float4 color, fixed4 topcol, fixed4 midcol, fixed4 btmcol)
{

	half maskR = lerp(0, topcol.a, color.r);
	half maskG = lerp(0, midcol.a, color.g);
	half maskB = lerp(0, btmcol.a, max(0, 1 - color.r - color.g));

	//RGBmask
	half maskRGB = smoothstep(0.9, 1, color.r) + smoothstep(0, (0.5 - _BlendFactor), max(0, maskR - maskB - maskG));
	maskRGB = min(maskRGB, 1.0);

	//GBmask
	half maskGB = max(0, smoothstep(0, 0.1, color.g) - smoothstep(0, 0.1, color.b))+ smoothstep(0, (0.5 - _BlendFactor), max(0, maskG - maskB - maskR));
	maskGB = min(maskGB, 1.0);

	return half2(maskGB, maskRGB);
}

inline fixed4 computeVBCol(fixed4 col, half3 ambient, half3 wNormal, half3 lightDir, half lightCal, half3 reflectLight)
{
	half3 nl = max(0, dot(wNormal, lightDir));
	half3 diffuse = nl * _LightColor0.rgb * lightCal + ambient;

	col.rgb *= diffuse;
	col.rgb += reflectLight;
	col.a = 1.0;

	return col;
}

inline fixed3 lightmapVBCol(fixed3 col, half3 wNormal, half3 lightDir, fixed shadow, half3 reflectLight, fixed3 lightmap, half lightmask)
{
	half3 nl = max(0, dot(wNormal, lightDir));
	half3 diffuse = nl * _LightColor0.rgb * lightmask * shadow + lightmap;

	col.rgb *= diffuse;
	col.rgb += reflectLight;

	return col;
}


/////////////FabricTranslucent//////////////////////////

inline fixed4 computeTFCol(fixed4 col, half3 ambient, half3 lightDir, half3 wNormal, fixed lightCal,
	fixed specular, fixed4 transTex)
{
	half3 nl = max(0, dot(wNormal, lightDir));
	half3 nlr = max(0, dot(-wNormal, lightDir));
	nlr = smoothstep(_TransArea, 1, nlr) * lightCal;

	half3 diffuse = nl * _LightColor0.rgb * lightCal + ambient;
	half3 trans = lerp(fixed3(0, 0, 0), _LightColor0.rgb * transTex * _TransColor.rgb, nlr);
	half3 Translucency = _TransPower * _LightColor0.rgb * transTex * _TransColor.rgb
		* pow(max(0.0, dot(lightDir, -wNormal)), _TransArea);
	Translucency = lerp(fixed3(0, 0, 0), Translucency, nlr);

	col.rgb *= diffuse;
	col.rgb += specular;
	col.rgb += trans;
	col.rgb += Translucency;

	return col;
}

inline fixed3 lightmapTFCol(fixed3 col, half3 lightDir, half3 wNormal, fixed lightCal,
	fixed specular, fixed4 transTex, fixed3 lightmap, half lightmask)
{
	half3 nl = max(0, dot(wNormal, lightDir));
	half3 nlr = max(0, dot(-wNormal, lightDir));
	nlr = smoothstep(_TransArea, 1, nlr) * lightCal;

	half3 diffuse = nl * _LightColor0.rgb * lightmask * lightCal + lightmap;
	half3 trans = lerp(fixed3(0, 0, 0), _LightColor0.rgb * transTex * _TransColor.rgb, nlr);
	half3 Translucency = _TransPower * _LightColor0.rgb * transTex * _TransColor.rgb
		* pow(max(0.0, dot(lightDir, -wNormal)), _TransArea);
	Translucency = lerp(fixed3(0, 0, 0), Translucency, nlr);

	col.rgb *= diffuse;
	col.rgb += specular;
	col.rgb += trans;
	col.rgb += Translucency;

	return col;
}

/////////////Simple Art//////////////////////////

struct appdata_SA
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	half3 normal : NORMAL;
	float4 tangent : TANGENT;

	#ifdef LIGHTMAP_ON
		half4 texcoord1 : TEXCOORD1;
	#endif
	#ifdef DYNAMICLIGHTMAP_ON
		half4 texcoord2 : TEXCOORD2;
	#endif

	UNITY_VERTEX_INPUT_INSTANCE_ID//VR
};

inline fixed4 computeSACol(fixed4 col, half3 ambient, half3 lightDir, half3 wNormal, fixed lightCal, half3 reflection,
	fixed reflMask, fixed specular)
{
	half3 nl = max(0, dot(wNormal, lightDir));

	half3 diffuse = nl * _LightColor0.rgb * lightCal + ambient;

	col.rgb *= diffuse;
	col.rgb = lerp(col.rgb, reflection, reflMask * _ReflectionIntensity);
	col.rgb += specular;

	return col;
}

inline fixed3 lightmapSACol(fixed3 col, half3 lightDir, half3 wNormal, fixed lightCal, half3 reflection,
	fixed reflMask, fixed specular, fixed3 lightmap, half lightmask)
{
	half3 nl = max(0, dot(wNormal, lightDir));
	half3 diffuse = nl * _LightColor0.rgb * lightmask * lightCal + lightmap;

	col.rgb *= diffuse;
	col.rgb = lerp(col.rgb, reflection, reflMask * _ReflectionIntensity);
	col.rgb += specular;

	return col;
}

#endif