#include <stdint.h>

typedef int8_t S8;
typedef int16_t S16;
typedef int32_t S32;
typedef int64_t S64;

typedef uint8_t U8;
typedef uint16_t U16;
typedef uint32_t U32;
typedef uint64_t U64;

typedef float F32;
typedef double F64;

typedef S8 B8;
typedef S16 B16;
typedef S32 B32;
typedef S64 B64;

typedef union V2 V2;
union __attribute((aligned(8))) V2
{
	struct
	{
		F32 x;
		F32 y;
	};
};

typedef union V2U64 V2U64;
union V2U64
{
	struct
	{
		U64 x;
		U64 y;
	};
};

typedef union V3 V3;
union __attribute((aligned(16))) V3
{
	struct
	{
		F32 x;
		F32 y;
		F32 z;
	};
	struct
	{
		F32 r;
		F32 g;
		F32 b;
	};
};

typedef union V4 V4;
union __attribute((aligned(16))) V4
{
	struct
	{
		F32 x;
		F32 y;
		F32 z;
		F32 w;
	};
	struct
	{
		F32 r;
		F32 g;
		F32 b;
		F32 a;
	};
};

#define v2(v0, v1) ((V2){.x = (v0), .y = (v1)})
#define v2u64(v0, v1) ((V2U64){.x = (v0), .y = (v1)})
#define v3(v0, v1, v2) ((V3){.x = (v0), .y = (v1), .z = (v2)})
#define v4(v0, v1, v2, v3) ((V4){.x = (v0), .y = (v1), .z = (v2), .w = (v3)})

typedef enum Axis2
{
	Axis2_X,
	Axis2_Y,
} Axis2;

#define function static
#define local_persist static
#define global static

#define Min(x, y) (((x) < (y)) ? (x) : (y))
#define Max(x, y) (((x) > (y)) ? (x) : (y))
#define Clamp(x, min, max) Min(Max((x), (min)), (max))

#define CeilF32 ceilf
#define CeilF64 ceil
#define RoundF32 roundf
#define RoundF64 round
#define FloorF32 floorf
#define FloorF64 floor
#define AbsF32 fabsf
#define AbsF64 fabs

function F32 MixF32(F32 x, F32 y, F32 a);

#define Kibibytes(n) ((U64)1024 * (n))
#define Mebibytes(n) ((U64)1024 * Kibibytes(n))
#define Gibibytes(n) ((U64)1024 * Mebibytes(n))

#define AlignPow2(n, align) (((n) + (align) - 1) & ~((align) - 1))
#define AlignPadPow2(n, align) ((0 - (n)) & ((align) - 1))

#define MemoryCopy(dst, src, size) (memmove((dst), (src), (size)))
#define MemoryCopyArray(dst, src, count) (MemoryCopy((dst), (src), sizeof(*(dst)) * (count)))
#define MemoryCopyStruct(dst, src) (MemoryCopyArray((dst), (src), 1))

#define MemorySet(dst, byte, size) (memset((dst), (byte), (size)))
#define MemoryZero(dst, size) (MemorySet((dst), 0, (size)))
#define MemoryZeroArray(dst, count) (MemoryZero((dst), sizeof(*(dst)) * (count)))
#define MemoryZeroStruct(dst) (MemoryZeroArray((dst), 1))

#define MemoryCompare(dst, src, size) (memcmp((dst), (src), (size)))
#define MemoryMatch(dst, src, size) (MemoryCompare((dst), (src), (size)) == 0)

#define Assert(b)                                                                                  \
	if (!(b))                                                                                  \
	{                                                                                          \
		__builtin_debugtrap();                                                             \
	}
