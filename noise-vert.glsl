#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform mat4 u_CamToWorld;    // The matrix that defines the camera's transformation.

uniform vec4 u_CamPos;
uniform float u_Time;        // time in seconds
uniform int u_Use4D;        // time in seconds

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_NorGeom;        // geometry normal
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_ViewVec;            // The color of each vertex. This is implicitly passed to the fragment shader.
out float isWater;
out float shininessMap;

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

//scratchapixel memory saving technique
//instead of saving 256x256x256 values, save array of only 256 of random lattice values
//then index into it using permutation table(premade hashtable) for each dimension
//indices 0-255 are mixed up and saved to the first half of the permutation table(taken from ken perlin)
//those same values are copied to the second half of the table(for dimensions 2 and above)
//for example: for a 3D position in space, each component gets mapped to an int
//that int should be in the range 0-255 somehow (could normalize and mult by 255)
//then get the other 7 cube positions and fetch each random lattice value by doing
// permutation[permutation[permutation[posx] + posy] + posz]
//optimization idea: you could probably make the permutation array 0-255 then do & 0xFF on the sum result
//to save memory and increase the chances of getting the same cache line on subsequent reads
const int permTabe[512] = int[512]( 151,160,137,91,90,15,
   131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
   190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
   88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
   77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
   102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
   135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
   5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
   223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
   129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
   251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
   49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
   138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,

   151,160,137,91,90,15,
   131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
   190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
   88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
   77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
   102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
   135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
   5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
   223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
   129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
   251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
   49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
   138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
   );

////scratchapixel: random direction in sphere
////printed to console and saved here to save on calcs
const vec3 latticeVals[256] = vec3[256](

vec3(0.00727041f, 0.963335f, 0.268202f),  vec3(-0.884132f, -0.37845f, 0.274019f),  vec3(0.321517f, -0.845779f, 0.425774f),  vec3(0.0648271f, -0.950795f, -0.302964f),
vec3(0.5295f, 0.217564f, 0.819937f),  vec3(-0.271293f, -0.933483f, 0.234541f),  vec3(-0.615555f, -0.747129f, -0.250778f),  vec3(0.0461704f, -0.0349421f, 0.998322f),
vec3(0.0648507f, -0.956964f, 0.282867f),  vec3(-0.0815315f, -0.642743f, -0.761731f),  vec3(0.921848f, -0.191739f, 0.336797f),  vec3(-0.249507f, -0.683976f, -0.68551f),
vec3(0.173146f, 0.932564f, -0.316773f),  vec3(0.990455f, 0.131338f, 0.0418227f),  vec3(-0.146783f, -0.385485f, 0.910965f),  vec3(0.830818f, -0.45208f, -0.324599f),

vec3(0.0182659f, 0.66926f, 0.742803f),  vec3(0.0993595f, 0.184835f, -0.977734f),  vec3(-0.224998f, -0.959162f, -0.171415f),  vec3(0.552467f, -0.0928238f, 0.82835f),
vec3(0.931159f, 0.151707f, -0.331553f),  vec3(-0.831895f, 0.544557f, -0.106815f),  vec3(-0.709814f, -0.210348f, -0.672249f),  vec3(0.782839f, -0.207459f, -0.58662f),
vec3(0.486433f, -0.250789f, -0.836952f),  vec3(0.375191f, 0.112165f, 0.920136f),  vec3(0.817955f, 0.103865f, -0.565827f),  vec3(-0.218586f, 0.952896f, -0.21026f),
vec3(-0.647232f, -0.762273f, -0.00558306f),  vec3(-0.718701f, 0.25017f, 0.648756f),  vec3(-0.627347f, -0.394534f, -0.671401f),  vec3(0.0215057f, -0.295136f, 0.955213f),

vec3(-0.841325f, -0.528471f, -0.113533f),  vec3(0.0916222f, -0.544749f, 0.833579f),  vec3(-0.306382f, 0.78189f, 0.542935f),  vec3(-0.926787f, 0.14486f, -0.346527f),
vec3(0.0338824f, -0.291554f, -0.955954f),  vec3(0.251758f, 0.88582f, 0.389795f),  vec3(-0.516198f, -0.609057f, 0.602154f),  vec3(0.302754f, -0.921036f, -0.245016f),
vec3(0.499552f, 0.236709f, 0.833317f),  vec3(-0.176147f, 0.84617f, -0.50296f),  vec3(-0.226548f, -0.585255f, -0.778558f),  vec3(0.0537729f, -0.89634f, -0.440095f),
vec3(0.00368655f, 0.351957f, 0.936009f),  vec3(0.814108f, -0.556861f, 0.164725f),  vec3(-0.00313186f, -0.904307f, 0.426871f),  vec3(-0.720903f, -0.228519f, 0.654276f),

vec3(0.891363f, 0.43049f, -0.141952f),  vec3(0.455505f, 0.793153f, -0.404257f),  vec3(-0.5474f, 0.378012f, -0.746632f),  vec3(-0.478329f, 0.276249f, -0.8336f),
vec3(-0.112616f, -0.316884f, -0.941755f),  vec3(0.387001f, 0.65449f, -0.649518f),  vec3(-0.813662f, 0.40146f, 0.420456f),  vec3(0.00197896f, 0.941901f, -0.335884f),
vec3(0.534276f, -0.62349f, 0.570797f),  vec3(0.693939f, 0.711241f, 0.112183f),  vec3(-0.979227f, 0.126933f, 0.158123f),  vec3(-0.553723f, 0.272791f, 0.786751f),
vec3(0.311534f, -0.769949f, 0.556888f),  vec3(0.928743f, -0.00850386f, 0.370626f),  vec3(0.187173f, 0.71899f, 0.669343f),  vec3(-0.647842f, 0.59968f, -0.46977f),

vec3(0.814023f, 0.579605f, 0.0377467f),  vec3(-0.122003f, -0.275265f, 0.953595f),  vec3(-0.689239f, -0.269874f, -0.672397f),  vec3(0.589487f, 0.803695f, -0.0811125f),
vec3(-0.248462f, -0.882659f, -0.398973f),  vec3(-0.827169f, 0.549361f, -0.118298f),  vec3(0.953227f, 0.0455255f, -0.298806f),  vec3(0.330646f, -0.845764f, 0.418756f),
vec3(0.725018f, 0.651149f, 0.224399f),  vec3(-0.746445f, 0.349073f, -0.56654f),  vec3(0.493486f, -0.0385772f, -0.868898f),  vec3(-0.203123f, -0.870172f, 0.448934f),
vec3(-0.583114f, 0.711364f, 0.392352f),  vec3(-0.955707f, -0.221882f, 0.193369f),  vec3(-0.0285002f, -0.0799257f, 0.996393f),  vec3(0.954924f, 0.291094f, -0.0581814f),

vec3(0.458142f, 0.0373383f, -0.888095f),  vec3(0.955725f, 0.211826f, -0.204252f),  vec3(0.188429f, -0.059843f, -0.980262f),  vec3(0.862648f, 0.195946f, 0.466309f),
vec3(0.111948f, 0.171829f, -0.978745f),  vec3(0.618185f, -0.723396f, 0.307483f),  vec3(-0.500109f, 0.865937f, -0.00665116f),  vec3(-0.095692f, -0.958061f, -0.270114f),
vec3(-0.152336f, -0.954116f, 0.257792f),  vec3(-0.327051f, 0.563227f, 0.758824f),  vec3(-0.933999f, -0.0291661f, -0.356082f),  vec3(0.547953f, 0.835361f, 0.0438132f),
vec3(0.713682f, -0.689927f, -0.121074f),  vec3(-0.53719f, -0.368114f, 0.758893f),  vec3(0.66459f, 0.672079f, -0.326542f),  vec3(0.508199f, -0.0621735f, -0.858992f),

vec3(-0.0863886f, 0.889579f, 0.448537f),  vec3(0.598319f, 0.502381f, -0.624202f),  vec3(0.687906f, -0.592523f, 0.419167f),  vec3(-0.902518f, -0.405635f, 0.144644f),
vec3(-0.619814f, -0.648604f, -0.44175f),  vec3(-0.443536f, 0.75993f, -0.475166f),  vec3(0.361397f, -0.828088f, 0.428558f),  vec3(-0.0346473f, -0.735239f, 0.676922f),
vec3(-0.655689f, -0.205182f, -0.726617f),  vec3(-0.0182952f, 0.756749f, -0.65345f),  vec3(0.110406f, -0.952685f, 0.2832f),  vec3(0.25272f, -0.95965f, -0.123306f),
vec3(-0.675151f, -0.696063f, 0.244269f),  vec3(0.767759f, -0.487651f, 0.415624f),  vec3(0.806436f, -0.506724f, -0.304781f),  vec3(0.517933f, 0.854231f, -0.0451056f),

vec3(-0.712149f, -0.692603f, -0.114646f),  vec3(0.966865f, 0.174814f, -0.186043f),  vec3(0.427738f, -0.519519f, -0.739689f),  vec3(-0.67099f, 0.258235f, 0.695045f),
vec3(-0.120734f, -0.451419f, 0.884106f),  vec3(0.437326f, -0.472934f, -0.764905f),  vec3(0.753597f, -0.473558f, 0.455889f),  vec3(0.628665f, 0.0503837f, -0.776043f),
vec3(-0.338725f, 0.406929f, 0.848336f),  vec3(-0.337859f, -0.197803f, 0.920177f),  vec3(0.578553f, 0.73388f, -0.355944f),  vec3(0.181554f, -0.943918f, -0.275785f),
vec3(0.197954f, 0.824964f, -0.529385f),  vec3(-0.510287f, -0.445011f, -0.735916f),  vec3(-0.869073f, 0.330636f, 0.367956f),  vec3(-0.449482f, -0.882663f, -0.137374f),

vec3(0.324326f, -0.313095f, -0.892628f),  vec3(-0.193608f, 0.975598f, 0.103556f),  vec3(0.340231f, -0.688338f, -0.640651f),  vec3(-0.110615f, 0.221307f, 0.96891f),
vec3(0.218225f, -0.366489f, -0.904469f),  vec3(0.516922f, -0.730896f, 0.445625f),  vec3(-0.54546f, 0.691697f, -0.473315f),  vec3(0.581819f, -0.812585f, 0.0345359f),
vec3(-0.13685f, 0.959204f, -0.247384f),  vec3(0.546854f, 0.354699f, -0.758379f),  vec3(-0.434047f, 0.166536f, -0.885364f),  vec3(0.00413703f, 0.656695f, -0.754145f),
vec3(-0.291225f, -0.373294f, 0.880818f),  vec3(0.231262f, -0.859892f, 0.455086f),  vec3(-0.162725f, 0.191237f, -0.967961f),  vec3(0.757383f, 0.313836f, -0.572607f),

vec3(0.538536f, 0.840016f, -0.0659647f),  vec3(-0.309097f, 0.146884f, -0.939619f),  vec3(0.0770558f, -0.0635308f, 0.995001f),  vec3(0.517959f, 0.449714f, 0.727651f),
vec3(-0.384973f, -0.73228f, -0.561748f),  vec3(0.0419224f, 0.998905f, -0.0207572f),  vec3(0.400816f, -0.915742f, 0.0276206f),  vec3(0.674809f, -0.549737f, -0.492364f),
vec3(0.662854f, -0.596881f, -0.45206f),  vec3(-0.627905f, 0.363075f, -0.688412f),  vec3(0.0253139f, -0.611196f, 0.791074f),  vec3(0.463155f, -0.292818f, 0.836508f),
vec3(-0.993557f, -0.109997f, -0.0273088f),  vec3(0.310672f, -0.0309722f, 0.950013f),  vec3(0.842299f, -0.297232f, 0.449651f),  vec3(0.567812f, -0.417893f, 0.709193f),

vec3(-0.691811f, -0.721331f, 0.0328529f),  vec3(0.465171f, 0.253814f, 0.848053f),  vec3(-0.461056f, 0.75892f, 0.459855f),  vec3(-0.00238052f, -0.991919f, -0.12685f),
vec3(0.798293f, -0.526658f, -0.292163f),  vec3(0.359809f, -0.188269f, 0.913834f),  vec3(0.632206f, -0.768043f, 0.102104f),  vec3(0.522286f, 0.137513f, -0.84161f),
vec3(-0.332519f, -0.326188f, 0.884891f),  vec3(0.458791f, -0.390815f, 0.797981f),  vec3(-0.0343677f, -0.649093f, -0.759932f),  vec3(0.655325f, 0.686776f, -0.314465f),
vec3(-0.799949f, 0.472792f, 0.369525f),  vec3(0.186072f, -0.955009f, 0.230944f),  vec3(-0.556633f, 0.0425051f, -0.82967f),  vec3(0.463779f, -0.659157f, 0.591965f),

vec3(0.227331f, -0.942107f, -0.246484f),  vec3(0.72631f, -0.676606f, 0.121154f),  vec3(0.12113f, 0.927636f, 0.353297f),  vec3(0.783196f, -0.269942f, -0.560121f),
vec3(-0.00763726f, 0.995607f, 0.0933191f),  vec3(-0.0751143f, 0.317028f, -0.945437f),  vec3(-0.967059f, 0.214198f, -0.137536f),  vec3(-0.289086f, -0.46783f, -0.835203f),
vec3(-0.548555f, 0.711202f, 0.439635f),  vec3(-0.624448f, -0.65393f, 0.42713f),  vec3(0.571022f, 0.0324826f, -0.820292f),  vec3(0.174992f, -0.814298f, -0.553441f),
vec3(-0.610522f, 0.738119f, 0.287131f),  vec3(-0.759245f, 0.624334f, -0.183723f),  vec3(-0.583336f, -0.46061f, -0.668997f),  vec3(-0.319113f, 0.224967f, 0.920628f),

vec3(-0.797372f, 0.0398913f, 0.602168f),  vec3(0.867242f, -0.391057f, -0.308164f),  vec3(-0.664142f, 0.498308f, 0.55732f),  vec3(-0.694531f, 0.690882f, 0.200772f),
vec3(-0.879562f, 0.328028f, -0.344627f),  vec3(0.49465f, 0.200773f, 0.845584f),  vec3(0.0803259f, 0.931131f, -0.355727f),  vec3(0.583823f, -0.785627f, -0.204797f),
vec3(0.991693f, -0.120399f, -0.0452624f),  vec3(0.898115f, -0.337981f, -0.281352f),  vec3(0.514822f, -0.0266444f, 0.856883f),  vec3(-0.569801f, -0.788417f, -0.231786f),
vec3(-0.606592f, -0.356294f, -0.710705f),  vec3(0.638114f, 0.769853f, -0.0116797f),  vec3(0.629452f, 0.445391f, -0.636723f),  vec3(0.297417f, -0.0565869f, -0.953069f),

vec3(0.038615f, -0.6857f, 0.726859f),  vec3(-0.773877f, -0.371301f, -0.513078f),  vec3(0.597302f, -0.692492f, 0.404579f),  vec3(-0.870129f, 0.37212f, -0.323113f),
vec3(-0.988258f, -0.144022f, 0.051017f),  vec3(-0.183363f, -0.848888f, 0.495748f),  vec3(0.782566f, 0.256435f, 0.567301f),  vec3(-0.0200946f, -0.909073f, 0.416153f),
vec3(0.686445f, -0.693323f, -0.219309f),  vec3(-0.0982159f, 0.240822f, -0.965587f),  vec3(0.270393f, 0.954733f, 0.123987f),  vec3(0.312878f, -0.0196236f, -0.949591f),
vec3(-0.690851f, 0.205842f, 0.693075f),  vec3(0.439361f, 0.142158f, 0.886991f),  vec3(0.71458f, 0.614252f, -0.334769f),  vec3(0.467687f, -0.329796f, 0.820063f),

vec3(0.904988f, 0.166007f, 0.391712f),  vec3(-0.852392f, 0.486144f, 0.192592f),  vec3(0.0819257f, -0.563762f, 0.821864f),  vec3(0.520078f, -0.578196f, -0.628656f),
vec3(0.573032f, -0.622061f, -0.533549f),  vec3(-0.0341981f, 0.966473f, -0.254482f),  vec3(0.625525f, 0.772111f, 0.112087f),  vec3(0.135563f, -0.98207f, 0.131004f),
vec3(-0.0694951f, 0.551607f, -0.831204f),  vec3(-0.676121f, -0.718593f, 0.162742f),  vec3(-0.0487213f, -0.0742775f, 0.996047f),  vec3(0.323093f, 0.939749f, 0.111727f),
vec3(0.31795f, 0.887596f, -0.333288f),  vec3(-0.117516f, 0.500563f, 0.857687f),  vec3(0.521354f, -0.567931f, 0.636903f),  vec3(0.234026f, -0.522126f, 0.820132f),

vec3(-0.294882f, -0.00535008f, 0.955519f),  vec3(0.96949f, 0.141524f, 0.200151f),  vec3(-0.11305f, 0.802081f, -0.586418f),  vec3(0.140081f, -0.0809432f, 0.986826f),
vec3(0.856857f, 0.460154f, -0.232497f),  vec3(0.955901f, 0.161155f, 0.245524f),  vec3(-0.629597f, -0.332675f, -0.702093f),  vec3(-0.576043f, -0.794079f, -0.193941f),
vec3(0.772861f, 0.175584f, -0.6098f),  vec3(-0.143251f, -0.785746f, 0.601733f),  vec3(-0.798608f, 0.311095f, -0.515213f),  vec3(0.691562f, -0.481613f, 0.538322f),
vec3(0.417491f, 0.907311f, 0.0498811f),  vec3(0.378208f, 0.0433136f, -0.924707f),  vec3(-0.0362783f, -0.75643f, -0.653067f),  vec3(-0.00490451f, -0.993475f, -0.113947f)

);


//////scratchapixel: random direction in sphere
//////printed to console and saved here to save on calcs
//const vec4 latticeVals4D[256] = vec4[256](
//
//vec4(0.00701192f,0.929085f,0.258667f,0.264277f),  vec4(-0.175222f,-0.830275f,0.104674f,0.518636f),  vec4(0.0501302f,-0.735242f,-0.23428f,0.63405f),  vec4(-0.32404f,-0.307153f,-0.813316f,0.373057f),
//vec4(-0.435628f,-0.528744f,-0.177476f,0.706513f),  vec4(-0.338576f,-0.436726f,0.697337f,0.456462f),  vec4(-0.0772669f,-0.609124f,-0.721888f,0.31918f),  vec4(0.19513f,0.299635f,0.863392f,0.355945f),
//vec4(0.172995f,0.931749f,-0.316497f,0.0417862f),  vec4(0.259484f,-0.0651365f,-0.896829f,0.352311f),  vec4(0.666951f,-0.362914f,-0.260577f,0.596296f),  vec4(0.71578f,0.0504343f,-0.427059f,-0.550215f),
//vec4(-0.173272f,-0.738656f,-0.132008f,0.637917f),  vec4(-0.13138f,0.218676f,0.679068f,-0.688322f),  vec4(-0.690394f,0.451931f,-0.0886461f,-0.557903f),  vec4(0.193176f,0.712331f,0.0634089f,0.671749f),
//vec4(0.357956f,-0.184551f,-0.615897f,0.677111f),  vec4(0.0597724f,0.29619f,-0.655048f,-0.69254f),  vec4(-0.218582f,0.952881f,-0.210256f,-0.00558292f),  vec4(0.455963f,-0.841686f,0.267126f,-0.110933f),
//vec4(-0.453644f,-0.285293f,-0.4855f,0.690728f),  vec4(-0.796354f,0.282604f,0.507191f,0.169447f),  vec4(0.0805199f,-0.478739f,0.73257f,0.477144f),  vec4(-0.436786f,0.811648f,-0.384013f,-0.0545898f),
//vec4(0.0315689f,-0.271647f,-0.890681f,0.363179f),  vec4(0.266684f,-0.73231f,-0.570167f,0.259828f),  vec4(0.232584f,-0.707565f,-0.188228f,0.640177f),  vec4(0.000240205f,0.467553f,-0.787739f,-0.401075f),
//vec4(-0.207356f,-0.535674f,-0.712601f,-0.402811f),  vec4(0.756523f,-0.127387f,0.455553f,-0.451571f),  vec4(0.748743f,-0.512151f,0.151499f,0.392598f),  vec4(0.426599f,-0.755709f,0.488469f,0.0911897f),
//vec4(0.826391f,0.399112f,-0.131605f,-0.374791f),  vec4(0.508576f,0.524128f,-0.655226f,-0.193183f),  vec4(-0.348218f,0.201107f,-0.606852f,-0.685588f),  vec4(0.34275f,0.685703f,0.318353f,-0.55766f),
//vec4(-0.771316f,0.380567f,0.398573f,-0.318403f),  vec4(0.173935f,-0.680682f,-0.409377f,0.58209f),  vec4(0.685423f,0.702513f,0.110806f,0.156183f),  vec4(0.793274f,-0.588615f,-0.0458801f,-0.148809f),
//vec4(0.292117f,-0.721959f,0.522178f,0.347525f),  vec4(0.076922f,-0.122283f,0.851584f,-0.50392f),  vec4(-0.647381f,0.599253f,-0.469436f,0.0377198f),  vec4(0.555913f,-0.062107f,-0.75672f,0.338347f),
//vec4(-0.686983f,-0.26899f,-0.670196f,-0.0808469f),  vec4(-0.212346f,0.623995f,-0.651746f,0.375188f),  vec4(-0.792544f,0.526365f,-0.113346f,-0.286298f),  vec4(-0.0337304f,-0.143954f,-0.840968f,0.520493f),
//vec4(0.630816f,0.566545f,0.195242f,-0.492929f),  vec4(0.652158f,0.286701f,-0.103705f,0.694073f),  vec4(-0.189089f,-0.810053f,0.417918f,0.365245f),  vec4(-0.773496f,-0.562283f,-0.284822f,0.0664666f),
//vec4(-0.0284521f,-0.0797908f,0.994711f,-0.0580831f),  vec4(0.283934f,0.104784f,-0.649182f,-0.697828f),  vec4(0.682502f,0.151269f,-0.14586f,-0.700024f),  vec4(-0.0264992f,-0.330826f,0.653029f,-0.680738f),
//vec4(0.107004f,0.16424f,-0.935519f,0.293903f),  vec4(-0.662083f,0.00221147f,0.677971f,-0.319369f),  vec4(-0.0926625f,-0.92773f,-0.261563f,0.24963f),  vec4(0.635673f,-0.564989f,0.418468f,-0.318736f),
//vec4(-0.933104f,-0.0291381f,-0.355741f,0.0437713f),  vec4(-0.544535f,0.207975f,-0.550414f,0.597723f),  vec4(-0.510654f,-0.34993f,0.721406f,-0.310412f),  vec4(0.432958f,0.206735f,-0.543402f,0.688856f),
//vec4(-0.0732836f,0.754632f,0.380495f,-0.529512f),  vec4(-0.11307f,-0.485397f,-0.619026f,0.606969f),  vec4(-0.825555f,-0.371044f,0.132309f,-0.40408f),  vec4(-0.0800256f,0.914399f,0.237192f,-0.318136f),
//vec4(0.299277f,-0.685748f,0.354893f,0.560566f),  vec4(0.568754f,0.665588f,0.474768f,0.0900337f),  vec4(-0.017603f,0.728114f,-0.628723f,0.272484f),  vec4(-0.686385f,0.267711f,0.458211f,0.497242f),
//vec4(-0.623447f,-0.642757f,0.225562f,0.383795f),  vec4(-0.266869f,0.369435f,0.628805f,0.630002f),  vec4(0.514563f,0.848672f,-0.044812f,-0.1139f),  vec4(-0.594677f,0.381241f,0.17356f,-0.686215f),
//vec4(0.351232f,-0.426598f,-0.607388f,0.570728f),  vec4(0.868904f,-0.298392f,-0.112815f,0.378472f),  vec4(0.397925f,-0.430326f,-0.695991f,0.414816f),  vec4(0.318222f,0.272163f,0.58093f,-0.697985f),
//vec4(-0.249256f,0.299445f,0.624262f,0.677127f),  vec4(-0.359346f,0.718157f,0.131884f,-0.581144f),  vec4(0.160457f,-0.834232f,-0.243738f,-0.46787f),  vec4(0.535467f,0.590591f,-0.563689f,0.216177f),
//vec4(-0.860987f,0.327559f,0.364532f,-0.136096f),  vec4(0.710211f,0.250603f,0.274572f,0.597836f),  vec4(-0.163022f,0.821476f,0.0871961f,-0.539442f),  vec4(0.724829f,-0.0456335f,0.600011f,-0.335451f),
//vec4(0.199329f,-0.334755f,-0.826151f,0.407039f),  vec4(-0.0649295f,0.695102f,0.659038f,-0.279797f),  vec4(0.564793f,-0.788806f,0.0335253f,-0.240145f),  vec4(0.497201f,0.47574f,-0.354481f,-0.633092f),
//vec4(-0.346547f,0.132963f,-0.706882f,-0.602116f),  vec4(0.782968f,-0.278008f,-0.485855f,0.271327f),  vec4(0.166167f,-0.617853f,0.32699f,-0.695503f),  vec4(0.158017f,0.704822f,-0.21038f,-0.658785f),
//vec4(0.392467f,0.612175f,-0.0480729f,-0.684763f),  vec4(0.783473f,0.0153196f,-0.115657f,0.610376f),  vec4(0.451585f,0.392086f,0.634406f,-0.489763f),  vec4(-0.835252f,0.0400433f,0.300721f,-0.458604f),
//vec4(0.359592f,-0.821559f,0.0247798f,-0.441725f),  vec4(-0.0808293f,0.499939f,0.615935f,0.603451f),  vec4(-0.492448f,0.28475f,-0.539902f,0.620417f),  vec4(0.594555f,-0.310417f,0.392124f,0.629591f),
//vec4(-0.720324f,-0.0797474f,-0.0197987f,0.688754f),  vec4(-0.0286446f,-0.214824f,0.718192f,0.661233f),  vec4(0.567505f,-0.417668f,0.708811f,0.0328352f),  vec4(0.668727f,-0.318668f,0.190956f,-0.644043f),
//vec4(-0.457391f,0.752887f,0.4562f,-0.125842f),  vec4(-0.419178f,0.534073f,0.382501f,0.626697f),  vec4(0.357948f,-0.187295f,0.909107f,0.101576f),  vec4(0.455301f,0.248966f,0.522605f,-0.676462f),
//vec4(-0.259909f,-0.254961f,0.691665f,0.623732f),  vec4(0.421937f,0.399777f,0.691479f,0.428958f),  vec4(0.614699f,0.6442f,-0.29497f,0.346617f),  vec4(-0.632195f,-0.585754f,-0.152786f,0.48361f),
//vec4(-0.478999f,0.0365768f,-0.713955f,0.509402f),  vec4(-0.4586f,0.436782f,0.596589f,0.492939f),  vec4(0.684827f,-0.637961f,0.114235f,0.333118f),  vec4(0.113255f,0.618508f,-0.407551f,0.66221f),
//vec4(-0.00554964f,0.723461f,0.0678106f,-0.687005f),  vec4(-0.8236f,0.36468f,-0.42797f,-0.0743828f),  vec4(-0.264641f,-0.428269f,-0.764577f,0.402459f),  vec4(-0.187522f,-0.907784f,-0.286014f,0.242815f),
//vec4(0.499611f,0.0284204f,-0.717708f,-0.484228f),  vec4(-0.480313f,-0.637093f,0.537354f,-0.273244f),  vec4(-0.63105f,0.518919f,-0.152702f,-0.556041f),  vec4(0.937386f,-0.205106f,0.201969f,-0.196079f),
//vec4(-0.762011f,0.0381222f,0.575463f,-0.294498f),  vec4(0.104718f,-0.49716f,0.83659f,-0.204901f),  vec4(-0.656631f,0.653181f,0.189816f,-0.325821f),  vec4(0.671076f,-0.326236f,-0.0891133f,-0.659761f),
//vec4(0.0786926f,0.912198f,-0.348494f,-0.200633f),  vec4(-0.51781f,0.0652355f,0.502934f,0.688967f),  vec4(0.681987f,-0.256647f,-0.213646f,0.650678f),  vec4(-0.16897f,0.146591f,0.93308f,0.28164f),
//vec4(-0.60655f,-0.35627f,-0.710656f,-0.0116788f),  vec4(0.221331f,0.491512f,-0.562287f,-0.627106f),  vec4(0.240579f,-0.0457729f,-0.770933f,0.587953f),  vec4(0.0276914f,0.852221f,0.504768f,0.134765f),
//vec4(0.568369f,-0.658948f,0.384982f,-0.307461f),  vec4(-0.974452f,-0.176162f,-0.133403f,0.04018f),  vec4(-0.159487f,-0.738351f,0.431195f,0.49343f),  vec4(-0.0927274f,-0.381581f,-0.809699f,0.436102f),
//vec4(0.493812f,-0.49876f,-0.157766f,-0.69462f),  vec4(-0.730711f,-0.317051f,-0.327452f,-0.508248f),  vec4(0.257153f,-0.0161286f,-0.780466f,0.569636f),  vec4(0.701493f,-0.233776f,-0.0722544f,-0.669354f),
//vec4(0.552545f,0.474967f,-0.258858f,0.634109f),  vec4(-0.137189f,-0.420161f,0.578082f,-0.685904f),  vec4(-0.658525f,0.375576f,0.148789f,0.63494f),  vec4(0.2646f,0.630009f,0.435308f,0.586158f),
//vec4(0.555332f,-0.602847f,-0.517069f,-0.246621f),  vec4(-0.658943f,-0.256933f,-0.399269f,-0.583406f),  vec4(0.104251f,-0.755237f,0.100745f,-0.639217f),  vec4(-0.740613f,-0.435747f,-0.449019f,0.244947f),
//vec4(-0.0484201f,-0.0738182f,0.989888f,0.111036f),  vec4(-0.345739f,0.58268f,-0.518337f,-0.5218f),  vec4(-0.0991191f,0.422202f,0.723421f,0.537199f),  vec4(0.501774f,-0.295961f,0.616231f,0.52999f),
//vec4(-0.289148f,-0.00524604f,0.936936f,0.196259f),  vec4(0.0710733f,0.262745f,-0.867308f,-0.416761f),  vec4(0.136442f,-0.0788404f,0.961189f,-0.226457f),  vec4(-0.273149f,-0.277527f,-0.61278f,-0.687655f),
//vec4(-0.61808f,-0.32659f,-0.689251f,-0.190394f),  vec4(0.232284f,0.660751f,0.214602f,-0.680733f),  vec4(-0.127343f,-0.698491f,0.534912f,-0.458f),  vec4(0.114155f,-0.767897f,-0.0963571f,0.622911f),
//vec4(0.306525f,0.666154f,0.036623f,-0.678926f),  vec4(0.109868f,0.213772f,-0.870189f,0.430117f),  vec4(-0.00414445f,-0.839515f,-0.0962885f,0.53472f),  vec4(-0.246439f,-0.761375f,-0.110445f,0.589388f),
//vec4(0.305264f,0.548509f,-0.507239f,0.590474f),  vec4(-0.965924f,-0.0364767f,-0.255928f,0.0127029f),  vec4(-0.760741f,0.376777f,0.474664f,0.232393f),  vec4(0.0455801f,-0.823666f,-0.138302f,0.54806f),
//vec4(-0.410788f,0.459522f,-0.437777f,0.654556f),  vec4(-0.460001f,0.81957f,0.183532f,0.288133f),  vec4(0.314852f,0.384201f,0.584029f,-0.642004f),  vec4(-0.54377f,-0.704666f,-0.317211f,0.327318f),
//vec4(-0.401005f,0.710456f,-0.515606f,-0.261912f),  vec4(0.667374f,0.24179f,-0.0543847f,0.702276f),  vec4(0.594324f,-0.449207f,0.575907f,0.336635f),  vec4(-0.194735f,-0.662221f,0.717364f,0.0944966f),
//vec4(-0.210033f,-0.000644396f,-0.866993f,0.451894f),  vec4(0.679483f,-0.574077f,0.0819858f,-0.449462f),  vec4(0.332486f,0.303491f,0.808052f,-0.379997f),  vec4(0.553954f,-0.77505f,0.0869885f,0.291316f),
//vec4(-0.900131f,0.142887f,-0.175852f,-0.372054f),  vec4(0.0175491f,0.692076f,0.450875f,0.563413f),  vec4(0.365595f,0.717008f,0.247707f,0.539333f),  vec4(0.741912f,-0.32865f,0.287978f,0.508551f),
//vec4(0.239981f,0.715412f,0.634201f,-0.168472f),  vec4(-0.554239f,0.500831f,-0.25193f,0.615238f),  vec4(-0.785021f,0.120054f,-0.453606f,0.40444f),  vec4(-0.174412f,0.277478f,0.867882f,0.373319f),
//vec4(0.549945f,-0.473685f,-0.186898f,0.662006f),  vec4(0.732497f,-0.624423f,-0.109901f,-0.247921f),  vec4(0.768364f,-0.0057687f,-0.338075f,-0.543404f),  vec4(0.466473f,-0.202621f,0.505332f,0.697128f),
//vec4(-0.755385f,-0.541732f,0.136167f,0.342605f),  vec4(0.184895f,0.776736f,-0.562172f,0.215541f),  vec4(-0.317145f,-0.696825f,0.103442f,-0.634945f),  vec4(-0.247632f,0.204366f,0.937769f,0.132294f),
//vec4(0.708425f,-0.0549466f,0.624248f,0.3247f),  vec4(0.00810264f,0.363494f,0.781517f,0.506988f),  vec4(-0.582192f,-0.654342f,0.243281f,-0.416778f),  vec4(0.13146f,-0.618192f,-0.685831f,0.360822f),
//vec4(0.418614f,0.404823f,-0.599789f,-0.548756f),  vec4(-0.486165f,-0.422199f,0.612045f,0.459121f),  vec4(-0.520997f,-0.713846f,-0.325146f,-0.33655f),  vec4(-0.0299908f,-0.556038f,-0.644213f,0.52432f),
//vec4(-0.451098f,0.557527f,-0.0258815f,0.696422f),  vec4(0.0591795f,-0.18853f,-0.803676f,-0.561301f),  vec4(-0.567499f,-0.45052f,0.632608f,0.273466f),  vec4(-0.142759f,0.147644f,0.67995f,-0.70391f),
//vec4(0.662534f,0.655166f,0.267025f,0.245974f),  vec4(-0.444949f,-0.398982f,-0.535933f,-0.59633f),  vec4(-0.80965f,-0.0107931f,0.00381143f,0.586801f),  vec4(0.00587478f,0.607015f,-0.412454f,-0.679249f),
//vec4(-0.587282f,0.641434f,0.373526f,0.322709f),  vec4(0.400164f,0.503945f,0.617111f,-0.45286f),  vec4(0.499912f,0.443004f,0.366494f,-0.647701f),  vec4(-0.197391f,-0.0931119f,0.689983f,0.690138f),
//vec4(0.935906f,0.324936f,0.0831543f,-0.107619f),  vec4(0.655713f,0.365863f,0.616195f,0.237673f),  vec4(0.520871f,0.465354f,0.113995f,-0.706501f),  vec4(0.107207f,0.891213f,0.41527f,0.14764f),
//vec4(-0.153761f,0.460815f,0.775576f,-0.4031f),  vec4(0.699288f,0.241345f,0.161377f,0.653228f),  vec4(0.0335875f,-0.00875373f,0.817939f,-0.574257f),  vec4(0.929384f,0.218017f,-0.297573f,0.0127848f),
//vec4(0.0287731f,0.745116f,-0.217731f,0.629736f),  vec4(0.61247f,-0.177544f,0.310653f,-0.704878f),  vec4(-0.569259f,-0.773698f,-0.240406f,-0.139789f),  vec4(-0.59978f,0.0512906f,0.798236f,0.0212888f),
//vec4(-0.451708f,-0.821924f,-0.115703f,0.327129f),  vec4(-0.39502f,-0.40202f,0.715661f,0.412514f),  vec4(0.386975f,0.432007f,0.78563f,-0.215422f),  vec4(-0.682781f,-0.0551073f,0.267479f,-0.677664f),
//vec4(0.316122f,-0.644464f,0.345375f,-0.604524f),  vec4(-0.797545f,0.576739f,-0.0115766f,0.176519f),  vec4(0.814755f,0.0748352f,0.0816088f,-0.569134f),  vec4(0.843572f,0.202014f,0.31763f,-0.382999f),
//vec4(0.0423931f,0.0204222f,0.719235f,0.693172f),  vec4(-0.47358f,0.435885f,0.623197f,-0.444243f),  vec4(0.694776f,-0.449151f,-0.0600356f,0.558521f),  vec4(0.0837672f,-0.439391f,0.567687f,-0.691122f),
//vec4(-0.233326f,-0.221882f,0.692291f,0.645803f),  vec4(0.51322f,-0.529054f,0.0366247f,-0.674808f),  vec4(0.0234966f,-0.770325f,0.00852177f,-0.637161f),  vec4(-0.660663f,0.40025f,-0.36116f,-0.522386f),
//vec4(-0.471552f,-0.0638862f,0.838749f,0.264685f),  vec4(-0.0686354f,-0.405682f,-0.59034f,-0.694414f),  vec4(-0.164872f,-0.113461f,0.943761f,-0.263172f),  vec4(0.0612928f,0.0587635f,0.812934f,-0.576132f)
//    
//);
//
//vec4 smoothStepRemap(const vec4 t) { 
//    return t * t * t * (t * (t * 6.f - 15.f) + 10.f); 
//}
//
//float PerlinNoise4DSample(vec4 P) {
//    //ultimately base coord (lower left) of lattice cell
//    //can't just cast to int b/c negatives wouldn't floor correctly 
//    //ex: int x = -1.4f; would be -1 when it should be -2 
//    //for the purposes of snapping to lower left lattice coord
//    vec4 floored = floor(P);
//
//    //want the relative location inside the lattice cell
//    P -= floored;
//
//    //important lattice coordinates, ANDing lower bits is the same as modulus for powers of 2
//    //modulus is expensive, worse than divide
//    ivec4 p0Coord = ivec4(floored) & 255;
//    ivec4 p1Coord = (p0Coord + 1) & 255;
//    
//    //remap uniform t value to warped t value to smooth the transitions
//    vec4 P_remap = smoothStepRemap(P);
//
//    //for 4D we need the 16 corners of the hypercube we are in
//    //nomenclature c0000 means corner x=0 y=0 z=0 w=0 or the base coord p0Coord
//    //where the numbers are offsets relative to the base corner
//    //c111 means corner x=1 y=1 z=1 w=1or the plus one coord p1Coord
//    //left corners (lower x)
//    vec4 c0000 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p0Coord.x]+p0Coord.y]+p0Coord.z]+p0Coord.w]];
//    vec4 c0010 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p0Coord.x]+p0Coord.y]+p1Coord.z]+p0Coord.w]];
//    vec4 c0100 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p0Coord.x]+p1Coord.y]+p0Coord.z]+p0Coord.w]];
//    vec4 c0110 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p0Coord.x]+p1Coord.y]+p1Coord.z]+p0Coord.w]];
//    //left corners (lower x, w=1)
//    vec4 c0001 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p0Coord.x]+p0Coord.y]+p0Coord.z]+p1Coord.w]];
//    vec4 c0011 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p0Coord.x]+p0Coord.y]+p1Coord.z]+p1Coord.w]];
//    vec4 c0101 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p0Coord.x]+p1Coord.y]+p0Coord.z]+p1Coord.w]];
//    vec4 c0111 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p0Coord.x]+p1Coord.y]+p1Coord.z]+p1Coord.w]];
//    //right corners (higher x)
//    vec4 c1000 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p1Coord.x]+p0Coord.y]+p0Coord.z]+p0Coord.w]];
//    vec4 c1010 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p1Coord.x]+p0Coord.y]+p1Coord.z]+p0Coord.w]];
//    vec4 c1100 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p1Coord.x]+p1Coord.y]+p0Coord.z]+p0Coord.w]];
//    vec4 c1110 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p1Coord.x]+p1Coord.y]+p1Coord.z]+p0Coord.w]];
//    //right corners (higher x, w=1)
//    vec4 c1001 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p1Coord.x]+p0Coord.y]+p0Coord.z]+p1Coord.w]];
//    vec4 c1011 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p1Coord.x]+p0Coord.y]+p1Coord.z]+p1Coord.w]];
//    vec4 c1101 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p1Coord.x]+p1Coord.y]+p0Coord.z]+p1Coord.w]];
//    vec4 c1111 = latticeVals4D[permTabe[permTabe[permTabe[permTabe[p1Coord.x]+p1Coord.y]+p1Coord.z]+p1Coord.w]];
//
//    //generate components of vectors from corners to P
//    float x0 = P.x, x1 = P.x - 1.0f; 
//    float y0 = P.y, y1 = P.y - 1.0f; 
//    float z0 = P.z, z1 = P.z - 1.0f; 
//    float w0 = P.w, w1 = P.w - 1.0f; 
//    
//    //generate vectors from corners to P in lattice cell
//    vec4 P0000 = vec4(x0, y0, z0, w0); 
//    vec4 P1000 = vec4(x1, y0, z0, w0); 
//    vec4 P0100 = vec4(x0, y1, z0, w0); 
//    vec4 P1100 = vec4(x1, y1, z0, w0); 
//    vec4 P0010 = vec4(x0, y0, z1, w0); 
//    vec4 P1010 = vec4(x1, y0, z1, w0); 
//    vec4 P0110 = vec4(x0, y1, z1, w0); 
//    vec4 P1110 = vec4(x1, y1, z1, w0); 
//    //w=1
//    vec4 P0001 = vec4(x0, y0, z0, w1); 
//    vec4 P1001 = vec4(x1, y0, z0, w1); 
//    vec4 P0101 = vec4(x0, y1, z0, w1); 
//    vec4 P1101 = vec4(x1, y1, z0, w1); 
//    vec4 P0011 = vec4(x0, y0, z1, w1); 
//    vec4 P1011 = vec4(x1, y0, z1, w1); 
//    vec4 P0111 = vec4(x0, y1, z1, w1); 
//    vec4 P1111 = vec4(x1, y1, z1, w1); 
//    
//    //dot the values at corners with the vectors from corners to point 
//    //P in the lattice cell
//
//    //8 edges along x axis
//    float x_000 = mix(dot(c0000, P0000), dot(c1000, P1000), P_remap.x); 
//    float x_100 = mix(dot(c0100, P0100), dot(c1100, P1100), P_remap.x); 
//    float x_010 = mix(dot(c0010, P0010), dot(c1010, P1010), P_remap.x); 
//    float x_110 = mix(dot(c0110, P0110), dot(c1110, P1110), P_remap.x); 
//    //w=1
//    float x_001 = mix(dot(c0001, P0001), dot(c1001, P1001), P_remap.x); 
//    float x_101 = mix(dot(c0101, P0101), dot(c1101, P1101), P_remap.x); 
//    float x_011 = mix(dot(c0011, P0011), dot(c1011, P1011), P_remap.x); 
//    float x_111 = mix(dot(c0111, P0111), dot(c1111, P1111), P_remap.x); 
//    
//    //lerp previous dimension results together along y axis
//    //8 previous values form 4 edges to lerp along
//    float y_00 = mix(x_000, x_100, P_remap.y); 
//    float y_10 = mix(x_010, x_110, P_remap.y); 
//    //w=1
//    float y_01 = mix(x_001, x_101, P_remap.y); 
//    float y_11 = mix(x_011, x_111, P_remap.y); 
//    
//    //lerp along z dimensions
//    //4 previoius values form 2 edges to lerp along
//    float z_0 = mix(y_00, y_10, P_remap.z);
//    float z_1 = mix(y_01, y_11, P_remap.z);
//
//    //finally, lerp along last dimension w
//    //using 2 previoius values to form an edge
//    return mix(z_0, z_1, P_remap.w);
//}
//
//
float PerlinNoise4D(vec4 P) {
    return 1.f;
}
//    float result = 0.f; 
//    int numlayer = 5; 
//    float rateOfChange = 2.0f; 
//    for (int i = 0; i < 5; ++i) { 
//        // change in frequency and amplitude
//        float freq = pow(rateOfChange, float(i));
//        result += PerlinNoise4DSample(P * freq) / freq; 
//    } 
//    return result;// * (1.0f / 1.934f);//normalize by the max possible magnitude
//}
//


//scratchapixel: recommends two differnt smoothing techniques from ken perlin
vec3 smoothStepRemap(const vec3 t) { 
    return t * t * t * (t * (t * 6.f - 15.f) + 10.f); 
    //return t * t * (3.f - 2.f * t); 
}

//scratchapixel: we need the relative position inside the lattice cell,
//the base coordinate in the lattice to key off of, remember to perform a 
//smoothstep on the relative position components to smooth transitions
//between cells, use ken perlins permutation table to generate 1:1 mapping between
//any 256x256x256 coordinate and an index into our lattice values(our gradients)

float PerlinNoise3DSample(vec3 P) {
    //ultimately base coord (lower left) of lattice cell
    //can't just cast to int b/c negatives wouldn't floor correctly 
    //ex: int x = -1.4f; would be -1 when it should be -2 
    //for the purposes of snapping to lower left lattice coord
    vec3 floored = floor(P);

    //want the relative location inside the lattice cell
    P -= floored;

    //important lattice coordinates, ANDing lower bits is the same as modulus for powers of 2
    //modulus is expensive, worse than divide
    ivec3 p0Coord = ivec3(floored) & 255;
    ivec3 p1Coord = (p0Coord + 1) & 255;
    
    //remap uniform t value to warped t value to smooth the transitions
    vec3 P_remap = smoothStepRemap(P);

    //for 3D we need the eight corners of the cube we are in
    //nomenclature c000 means corner x=0 y=0 z=0 or the base coord p0Coord
    //where the numbers are offsets relative to the base corner
    //c111 means corner x=1 y=1 z=1 or the plus one coord p1Coord
    //TODO: try just getting the address instead of copying
    //left corners (lower x)
    vec3 c000 = latticeVals[permTabe[permTabe[permTabe[p0Coord.x]+p0Coord.y]+p0Coord.z]];
    vec3 c001 = latticeVals[permTabe[permTabe[permTabe[p0Coord.x]+p0Coord.y]+p1Coord.z]];
    vec3 c010 = latticeVals[permTabe[permTabe[permTabe[p0Coord.x]+p1Coord.y]+p0Coord.z]];
    vec3 c011 = latticeVals[permTabe[permTabe[permTabe[p0Coord.x]+p1Coord.y]+p1Coord.z]];
    //right corners (higher x)
    vec3 c100 = latticeVals[permTabe[permTabe[permTabe[p1Coord.x]+p0Coord.y]+p0Coord.z]];
    vec3 c101 = latticeVals[permTabe[permTabe[permTabe[p1Coord.x]+p0Coord.y]+p1Coord.z]];
    vec3 c110 = latticeVals[permTabe[permTabe[permTabe[p1Coord.x]+p1Coord.y]+p0Coord.z]];
    vec3 c111 = latticeVals[permTabe[permTabe[permTabe[p1Coord.x]+p1Coord.y]+p1Coord.z]];

    //generate components of vectors from corners to P
    float x0 = P.x, x1 = P.x - 1.0f; 
    float y0 = P.y, y1 = P.y - 1.0f; 
    float z0 = P.z, z1 = P.z - 1.0f; 
    
    //generate vectors from corners to P in lattice cell
    vec3 P000 = vec3(x0, y0, z0); 
    vec3 P100 = vec3(x1, y0, z0); 
    vec3 P010 = vec3(x0, y1, z0); 
    vec3 P110 = vec3(x1, y1, z0); 
    vec3 P001 = vec3(x0, y0, z1); 
    vec3 P101 = vec3(x1, y0, z1); 
    vec3 P011 = vec3(x0, y1, z1); 
    vec3 P111 = vec3(x1, y1, z1); 
    
    //dot the values at corners with the vectors from corners to point 
    //P in the lattice cell

    //4 edges along x axis
    float x_00 = mix(dot(c000, P000), dot(c100, P100), P_remap.x); 
    float x_10 = mix(dot(c010, P010), dot(c110, P110), P_remap.x); 
    float x_01 = mix(dot(c001, P001), dot(c101, P101), P_remap.x); 
    float x_11 = mix(dot(c011, P011), dot(c111, P111), P_remap.x); 
    
    //lerp previous dimension results together along y axis
    //4 previous values form 2 edges to lerp along
    float y_0 = mix(x_00, x_10, P_remap.y); 
    float y_1 = mix(x_01, x_11, P_remap.y); 
    
    //finally, lerp along z dimensions
    //2 previoius values form an edge to lerp along
    return mix(y_0, y_1, P_remap.z);
}

float PerlinNoise3D(vec3 P) {
    float result = 0.f; 
    int numlayer = 5; 
    float rateOfChange = 2.0f; 
    for (int i = 0; i < 5; ++i) { 
        // change in frequency and amplitude
        float freq = pow(rateOfChange, float(i));
        result += PerlinNoise3DSample(P * freq) / freq; 
    } 
    return result;// * (1.0f / 1.934f);//normalize by the max possible magnitude
}

//colors
const vec4 theColors[8] = vec4[8] (
//ocean
vec4(0.08f, 0.08f, 0.44f, 1.00f), //deep
vec4(0.00f, 0.00f, 0.50f, 1.00f), //deep
vec4(0.28f, 0.51f, 0.71f, 1.00f), //med
vec4(0.53f, 0.81f, 0.98f, 1.00f), //shallow

//land
vec4(1.00f, 0.89f, 0.71f, 1.00f), //desert/rock
vec4(0.00f, 0.55f, 0.13f, 1.00f), //forrest
vec4(0.90f, 0.90f, 0.98f, 1.00f), //ice
vec4(1.00f, 0.98f, 0.98f, 1.00f) //snow
);
   
void main()
{
    mat3 invTranspose = mat3(u_ModelInvTr);
    vec3 vs_Nor3 = vec3(vs_Nor);
    vec3 tan = cross(vs_Nor3, vec3(0.f, 1.f, 0.f));
    tan = length(tan) < 0.01f ? cross(vs_Nor3, vec3(0.f, 0.f, -1.f)) : tan;
    tan = normalize(tan);
    vec3 bitan = normalize(cross(vs_Nor3, tan));
    mat3 tanToModel = mat3(tan, bitan, vs_Nor3);

    //displace vs_Pos according to noise value
    vec3 vs_Pos3 = vec3(vs_Pos);
    float scale = 2.f;
    float waterScale = 8.f*scale;
    float perlin = u_Use4D == 1 ? -PerlinNoise4D(vec4(vs_Pos3, u_Time)*scale) : -PerlinNoise3D(vs_Pos3*scale);
    float waterPerlin = u_Use4D == 1 ? PerlinNoise4D(vec4(vs_Pos3, u_Time)*waterScale) : PerlinNoise3D(vs_Pos3*waterScale);

    shininessMap = clamp(-perlin + 0.3f, 0.f, 1.f);
    isWater = perlin <= 0.f ? 1.f : 0.f;

    //calculate the gradient on the surface to get the shading normal
    float norScale = isWater == 0.f ? scale : waterScale;
    float time = u_Time * (1.f/100.f);
    float e = 0.00001f;
    vec3 vs_Pos3XL = vs_Pos3 - vec3(e, 0.f, 0.f);
    vec3 vs_Pos3YL = vs_Pos3 - vec3(0.f, e, 0.f);
    vec3 vs_Pos3ZL = vs_Pos3 - vec3(0.f, 0.f, e);
    float perlinXL = (u_Use4D == 1 ) ? -PerlinNoise4D(vec4(vs_Pos3XL, time)*norScale) : -PerlinNoise3D(vs_Pos3XL*norScale);
    float perlinYL = (u_Use4D == 1 ) ? -PerlinNoise4D(vec4(vs_Pos3YL, time)*norScale) : -PerlinNoise3D(vs_Pos3YL*norScale);
    float perlinZL = (u_Use4D == 1 ) ? -PerlinNoise4D(vec4(vs_Pos3ZL, time)*norScale) : -PerlinNoise3D(vs_Pos3ZL*norScale);
    vec3 vs_Pos3XR = vs_Pos3 + vec3(e, 0.f, 0.f);
    vec3 vs_Pos3YR = vs_Pos3 + vec3(0.f, e, 0.f);
    vec3 vs_Pos3ZR = vs_Pos3 + vec3(0.f, 0.f, e);
    float perlinXR = (u_Use4D == 1 ) ? -PerlinNoise4D(vec4(vs_Pos3XR, time)*norScale) : -PerlinNoise3D(vs_Pos3XR*norScale);
    float perlinYR = (u_Use4D == 1 ) ? -PerlinNoise4D(vec4(vs_Pos3YR, time)*norScale) : -PerlinNoise3D(vs_Pos3YR*norScale);
    float perlinZR = (u_Use4D == 1 ) ? -PerlinNoise4D(vec4(vs_Pos3ZR, time)*norScale) : -PerlinNoise3D(vs_Pos3ZR*norScale);


    float dampen = 1.f/(2.f*norScale);
    float landOffset = clamp(dampen*perlin, 0.f, 1.f);
    float landOffsetXL = clamp(dampen*perlinXL, 0.f, 1.f);
    float landOffsetYL = clamp(dampen*perlinYL, 0.f, 1.f);
    float landOffsetZL = clamp(dampen*perlinZL, 0.f, 1.f);
    float landOffsetXR = clamp(dampen*perlinXR, 0.f, 1.f);
    float landOffsetYR = clamp(dampen*perlinYR, 0.f, 1.f);
    float landOffsetZR = clamp(dampen*perlinZR, 0.f, 1.f);
    vec3 dF = vec3(landOffsetXL-landOffsetXR, landOffsetYL-landOffsetYR, landOffsetZL-landOffsetZR) * (1.f/e);
    dF = tanToModel * dF;
    

    vec3 shadeNor3 = isWater == 1.f ? vs_Nor3 : normalize(vs_Nor3-dF);
    //vec3 shadeNor3 = normalize(vs_Nor3-dF);
    fs_Nor = vec4(invTranspose*shadeNor3, 0.f);       
    fs_NorGeom = vec4(invTranspose * vs_Nor3, 0.f);       


    //wood noise for water
    float waterNoise = -perlinXL*1.f;
    waterNoise = waterNoise - floor(waterNoise);
    int waterIndex = int((-waterNoise + 1.f) * 4.f);
    vec4 deep   = vec4(0.08f, 0.08f, 0.44f, 1.00f);
    vec4 shallow = vec4(0.53f, 0.81f, 0.98f, 1.00f);

    int index = int(8.f*(0.5f*(perlin+1.f)-0.01f));
    fs_Col = isWater == 1.f ? mix(deep, shallow, waterNoise) : theColors[index];
    //float mapVal = (0.5f*(perlinZ+1.f)-0.01f);
    //fs_Col = vec4(mapVal, mapVal, mapVal, 1.f);

    vec3 offset = landOffset*vs_Nor3;
    vec4 newPos = vec4(vs_Pos3 + offset, 1.f);

    vec4 modelposition = u_Model * newPos;   // Temporarily store the transformed vertex positions for use below
    //fs_ViewVec = normalize(u_CamPos - modelposition);
    fs_ViewVec = normalize(u_CamToWorld[3] - modelposition);
    //fs_ViewVec = normalize(vec4(0.f,0.f,0.f,1.f) - modelposition);

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
