#version 300 es

precision highp float;
uniform mat4 u_View;
uniform mat4 u_CamToWorld;
uniform float u_Time;
uniform float u_ScreenWidth;
uniform float u_ScreenHeight;
uniform float u_PixelLenX;
uniform float u_PixelLenY;



out vec4 outCol;

//these assume point p is in object space and object is centered on origin
float sdSphere(vec3 p, float radius) {
	return length(p) - radius;
}
float sdCylinder(vec3 p, vec3 c) {
	return length(p.xz - c.xy) - c.z;
}
float sdCappedCylinder( vec3 p, vec2 h ) {//h is radius,height
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}
float sdCapsule( vec3 p, vec3 a, vec3 b, float r ) {//end a, end b, radius
    vec3 pa = p - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}
float sdTriPrism( vec3 p, vec2 h ) {//h = radius, height
    vec3 q = abs(p);
    return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}
float sdTorus(vec3 p, vec2 t) {//t = circle radius, tube radius
	vec2 q = vec2(length(p.xz)-t.x, p.y);
	return length(q) - t.y;
}
float sdBox(vec3 p, vec3 b) { //b must be box xyz dims
	vec3 d = abs(p) - b;
	return min(max(d.x, max(d.y,d.z)), 0.f) + length(max(d, 0.f));
}
float sdEllipsoid(vec3 p, vec3 r) {//dist from center to ortho edges, axis scalings
	return (length(p/r)-1.f) * min(min(r.x,r.y), r.z);
}

//wrapper func to call specific primitve func


//operations
//union
float opU( float d1, float d2 ) {//both shapes together
    return min(d1,d2);
}
//subtraction
float opS( float d1, float d2 ) {//second subtracted from first
    return max(d1,-d2);
}
//intersection
float opI( float d1, float d2 ) {//region in space occupied by both
    return max(d1,d2);
}
////repetition
vec3 opRep( vec3 p, vec3 c ) {//pass to sd func
    vec3 q = mod(p,c)-0.5*c;
    //return primitive( q );
	return q;
}
////rot/trans
//vec3 opTx( vec3 p, mat4 m ) {//pass to sd func
//    return = invert(m)*p;
//}
//float opScale( vec3 p, float s ) {
//    return primitive(p/s)*s;
//}

vec3 opTwist( vec3 p ) {//pass to sd func
    float c = cos(1.0*p.y);
    float s = sin(1.0*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xz,p.y);
    //return primitive(q);
    return q;
}
vec3 opCheapBend( vec3 p ) {//pass to sd func
    float c = cos(20.0*p.y);
    float s = sin(20.0*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xy,p.z);
    //return primitive(q);
	return q;
}


float sceneSDF(vec3 point, out int materialID) {
	//get distances for each object in scene

	//object 0: white sphere
	int obj0ID = 0;
	//upload or store array of inverse model matrices
	//multiply point by it and pass result into sd func
	vec3 p_rep = opRep(point, vec3(0.0, 0.0, 5.0));
	vec3 p_twist = opTwist(point);
	vec3 p_rep_twist = opTwist(p_rep);

	vec3 p = p_rep_twist;
	//float obj0Dist = opS(opI(sdSphere(p, 1.f), sdBox(p,vec3(0.8))), sdCappedCylinder(p, vec2(0.2, 2.0)));
	float obj0Dist = opS(opI(sdSphere(p, 1.f), sdBox(p,vec3(0.8))), sdCappedCylinder(p, vec2(0.2, 2.0)));

	//float obj0Dist = sdSphere(point, 1.f);
	//float obj0Dist = sdBox(point, vec3(0.8f));
	//float obj0Dist = sdCappedCylinder(point, vec2(0.2f,2.0f));//rad,h
	//float obj0Dist = sdCapsule(point, vec3(0.0,0.0,0.0), vec3(-1.0,0.0,0.0), 1.0);//end a, end b, rad
	//float obj0Dist = sdTriPrism(point, vec2(1.0,3.0));//radius, height
	//float obj0Dist = sdTorus(point, vec2(1.0,0.2));//circle radius,tube radius 
	//float obj0Dist = sdEllipsoid(point, vec3(2.0,1.0,0.5));//axis scalings
	



	float closest = obj0Dist;
	materialID = obj0ID;


	//determine object that was closest and set the material
	return closest;
}

const vec4 materialColors[1] = vec4[1](
	vec4(0.f, 1.f, 1.f,1.f)
);

void main() {
	//get ray
	vec3 rightDir = vec3(u_CamToWorld[0]);
	vec3 upDir = vec3(u_CamToWorld[1]);
	vec3 viewDir = -vec3(u_CamToWorld[2]);
	vec3 rayOrig = vec3(u_CamToWorld[3]);
	//lower left is 0,0 for gl_FragCoord
	vec3 horizOffset = rightDir * u_PixelLenX * (gl_FragCoord.x - u_ScreenWidth*0.5f);
	vec3 vertOffset  = upDir * u_PixelLenY * (gl_FragCoord.y - u_ScreenHeight*0.5f);
	vec3 rayDir = normalize(viewDir + horizOffset + vertOffset);

	float depth = 0.f;
	float end = 1000.f;
	float EPSILON = 0.01f;
	const int BACKGROUND = -1;
	int materialID = 0;
	for(int i = 0; i < 100; ++i) {
		float dist = sceneSDF(rayOrig + depth * rayDir, materialID);
		if(dist < EPSILON) {
			break;
		}
		depth +=dist;

		if(depth >= end) {
			materialID = BACKGROUND;
			depth = end;
			break;
		}
	}
	
	vec3 lightPos = rayOrig+vec3(2.f, 2.f, 0.f);
	vec3 point = rayOrig + depth*rayDir;
	vec3 lightDir = normalize(lightPos - point);
	vec3 materialColor = materialID<0 ? vec3(1.f, 0.5f, 0.f) : vec3(materialColors[materialID]);

	vec3 normal = normalize(point);
	vec3 diff = materialColor * max(dot(lightDir, normal), 0.f);

	vec3 ambient = 0.2f * materialColor;
	vec3 spec = vec3(0.f);
	vec3 emissive = vec3(0.f);
	vec4 finalColor = vec4(diff + ambient + spec + emissive, 1.f);
	outCol = materialID < 0 ? vec4(1.0, 0.5, 0.0, 1.0) : finalColor;
	//outCol = vec4(1.0, 0.5, 0.0, 1.0);
}
////from jamie wong example
////Return the normalized direction to march in from the eye point for a single pixel.
////fieldOfView: vertical field of view in degrees
////size: resolution of the output image
////fragCoord: the x,y coordinate of the pixel in the output image
//vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
//    vec2 xy = fragCoord - size / 2.0;
//    float z = size.y / tan(radians(fieldOfView) / 2.0);
//    return normalize(vec3(xy, -z));
//}