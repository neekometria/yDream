// Unique tag for persistent voxel radiance across dimension changes.
// ID 0 is reserved for cleared/uninitialized image data.
#ifndef YD_WORLD_ID
    #if defined NETHER
        #define YD_WORLD_ID 2.0
    #elif defined THE_END
        #define YD_WORLD_ID 3.0
    #elif defined NORTHSTAR_MOON
        #define YD_WORLD_ID 4.0
    #elif defined NORTHSTAR_MARS
        #define YD_WORLD_ID 5.0
    #elif defined NORTHSTAR_MERCURY
        #define YD_WORLD_ID 6.0
    #elif defined NORTHSTAR_VENUS
        #define YD_WORLD_ID 7.0
    #elif defined NORTHSTAR_ORBIT_EARTH
        #define YD_WORLD_ID 8.0
    #elif defined NORTHSTAR_ORBIT_MARS
        #define YD_WORLD_ID 9.0
    #elif defined NORTHSTAR_ORBIT_MERCURY
        #define YD_WORLD_ID 10.0
    #elif defined NORTHSTAR_ORBIT_VENUS
        #define YD_WORLD_ID 11.0
    #elif defined NORTHSTAR_ORBIT
        #define YD_WORLD_ID 12.0
    #elif defined UNKNOWN_DIM
        #define YD_WORLD_ID 13.0
    #else
        #define YD_WORLD_ID 1.0
    #endif
#endif
