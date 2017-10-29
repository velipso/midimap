// (c) Copyright 2017, Sean Connelly (@voidqk), http://syntheti.cc
// MIT License
// Project Home: https://github.com/voidqk/midimap

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#import <Foundation/Foundation.h>
#include <CoreMIDI/CoreMIDI.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <signal.h>


#define TODO(s)   fprintf(stderr, "TODO: " s "\n"); abort();


#define EACH_LCC(X)      \
	X(_Any       ,   -1) \
	X(Pedal      , 0x40) \
	X(Portamento , 0x41) \
	X(Sostenuto  , 0x42) \
	X(SoftPedal  , 0x43) \
	X(Legato     , 0x44) \
	X(Hold2      , 0x45) \
	X(Sound1     , 0x46) \
	X(Sound2     , 0x47) \
	X(Sound3     , 0x48) \
	X(Sound4     , 0x49) \
	X(Sound5     , 0x4A) \
	X(Sound6     , 0x4B) \
	X(Sound7     , 0x4C) \
	X(Sound8     , 0x4D) \
	X(Sound9     , 0x4E) \
	X(Sound10    , 0x4F) \
	X(General5   , 0x50) \
	X(General6   , 0x51) \
	X(General7   , 0x52) \
	X(General8   , 0x53) \
	X(Portamento2, 0x54) \
	X(Undefined1 , 0x55) \
	X(Undefined2 , 0x56) \
	X(Undefined3 , 0x57) \
	X(VelocityLow, 0x58) \
	X(Undefined4 , 0x59) \
	X(Undefined5 , 0x5A) \
	X(Effect1    , 0x5B) \
	X(Effect2    , 0x5C) \
	X(Effect3    , 0x5D) \
	X(Effect4    , 0x5E) \
	X(Effect5    , 0x5F)

#define EACH_HCC(X)                \
	X(_Any           ,   -1,   -2) \
	X(Bank           , 0x00, 0x20) \
	X(Mod            , 0x01, 0x21) \
	X(Breath         , 0x02, 0x22) \
	X(Undefined6     , 0x03, 0x23) \
	X(Foot           , 0x04, 0x24) \
	X(PortamentoTime , 0x05, 0x25) \
	X(ChannelVolume  , 0x07, 0x27) \
	X(Balance        , 0x08, 0x28) \
	X(Undefined7     , 0x09, 0x29) \
	X(Pan            , 0x0A, 0x2A) \
	X(Expression     , 0x0B, 0x2B) \
	X(Effect6        , 0x0C, 0x2C) \
	X(Effect7        , 0x0D, 0x2D) \
	X(Undefined8     , 0x0E, 0x2E) \
	X(Undefined9     , 0x0F, 0x2F) \
	X(General1       , 0x10, 0x30) \
	X(General2       , 0x11, 0x31) \
	X(General3       , 0x12, 0x32) \
	X(General4       , 0x13, 0x33) \
	X(Undefined10    , 0x14, 0x34) \
	X(Undefined11    , 0x15, 0x35) \
	X(Undefined12    , 0x16, 0x36) \
	X(Undefined13    , 0x17, 0x37) \
	X(Undefined14    , 0x18, 0x38) \
	X(Undefined15    , 0x19, 0x39) \
	X(Undefined16    , 0x1A, 0x3A) \
	X(Undefined17    , 0x1B, 0x3B) \
	X(Undefined18    , 0x1C, 0x3C) \
	X(Undefined19    , 0x1D, 0x3D) \
	X(Undefined20    , 0x1E, 0x3E) \
	X(Undefined21    , 0x1F, 0x3F)

#define EACH_RPN(X)                 \
	X(_Any            ,   -1,   -2) \
	X(BendRange       , 0x00, 0x00) \
	X(FineTuning      , 0x00, 0x01) \
	X(CoarseTuning    , 0x00, 0x02) \
	X(TuningProgram   , 0x00, 0x03) \
	X(TuningBank      , 0x00, 0x04) \
	X(ModRange        , 0x00, 0x05) \
	X(Azimuth         , 0x3D, 0x00) \
	X(Elevation       , 0x3D, 0x01) \
	X(Gain            , 0x3D, 0x02) \
	X(DistanceRatio   , 0x3D, 0x03) \
	X(MaxDistance     , 0x3D, 0x04) \
	X(GainAtMax       , 0x3D, 0x05) \
	X(RefDistanceRatio, 0x3D, 0x06) \
	X(PanSpread       , 0x3D, 0x07) \
	X(Roll            , 0x3D, 0x08) \
	X(Empty           , 0x7F, 0x7F)

#define EACH_NOTE(X)  \
	X(_Any,  -1)      \
	X( CN2,   0)      \
	X(DbN2,   1)      \
	X( DN2,   2)      \
	X(EbN2,   3)      \
	X( EN2,   4)      \
	X( FN2,   5)      \
	X(GbN2,   6)      \
	X( GN2,   7)      \
	X(AbN2,   8)      \
	X( AN2,   9)      \
	X(BbN2,  10)      \
	X( BN2,  11)      \
	X( CN1,  12)      \
	X(DbN1,  13)      \
	X( DN1,  14)      \
	X(EbN1,  15)      \
	X( EN1,  16)      \
	X( FN1,  17)      \
	X(GbN1,  18)      \
	X( GN1,  19)      \
	X(AbN1,  20)      \
	X( AN1,  21)      \
	X(BbN1,  22)      \
	X( BN1,  23)      \
	X( C0 ,  24)      \
	X(Db0 ,  25)      \
	X( D0 ,  26)      \
	X(Eb0 ,  27)      \
	X( E0 ,  28)      \
	X( F0 ,  29)      \
	X(Gb0 ,  30)      \
	X( G0 ,  31)      \
	X(Ab0 ,  32)      \
	X( A0 ,  33)      \
	X(Bb0 ,  34)      \
	X( B0 ,  35)      \
	X( C1 ,  36)      \
	X(Db1 ,  37)      \
	X( D1 ,  38)      \
	X(Eb1 ,  39)      \
	X( E1 ,  40)      \
	X( F1 ,  41)      \
	X(Gb1 ,  42)      \
	X( G1 ,  43)      \
	X(Ab1 ,  44)      \
	X( A1 ,  45)      \
	X(Bb1 ,  46)      \
	X( B1 ,  47)      \
	X( C2 ,  48)      \
	X(Db2 ,  49)      \
	X( D2 ,  50)      \
	X(Eb2 ,  51)      \
	X( E2 ,  52)      \
	X( F2 ,  53)      \
	X(Gb2 ,  54)      \
	X( G2 ,  55)      \
	X(Ab2 ,  56)      \
	X( A2 ,  57)      \
	X(Bb2 ,  58)      \
	X( B2 ,  59)      \
	X( C3 ,  60)      \
	X(Db3 ,  61)      \
	X( D3 ,  62)      \
	X(Eb3 ,  63)      \
	X( E3 ,  64)      \
	X( F3 ,  65)      \
	X(Gb3 ,  66)      \
	X( G3 ,  67)      \
	X(Ab3 ,  68)      \
	X( A3 ,  69)      \
	X(Bb3 ,  70)      \
	X( B3 ,  71)      \
	X( C4 ,  72)      \
	X(Db4 ,  73)      \
	X( D4 ,  74)      \
	X(Eb4 ,  75)      \
	X( E4 ,  76)      \
	X( F4 ,  77)      \
	X(Gb4 ,  78)      \
	X( G4 ,  79)      \
	X(Ab4 ,  80)      \
	X( A4 ,  81)      \
	X(Bb4 ,  82)      \
	X( B4 ,  83)      \
	X( C5 ,  84)      \
	X(Db5 ,  85)      \
	X( D5 ,  86)      \
	X(Eb5 ,  87)      \
	X( E5 ,  88)      \
	X( F5 ,  89)      \
	X(Gb5 ,  90)      \
	X( G5 ,  91)      \
	X(Ab5 ,  92)      \
	X( A5 ,  93)      \
	X(Bb5 ,  94)      \
	X( B5 ,  95)      \
	X( C6 ,  96)      \
	X(Db6 ,  97)      \
	X( D6 ,  98)      \
	X(Eb6 ,  99)      \
	X( E6 , 100)      \
	X( F6 , 101)      \
	X(Gb6 , 102)      \
	X( G6 , 103)      \
	X(Ab6 , 104)      \
	X( A6 , 105)      \
	X(Bb6 , 106)      \
	X( B6 , 107)      \
	X( C7 , 108)      \
	X(Db7 , 109)      \
	X( D7 , 110)      \
	X(Eb7 , 111)      \
	X( E7 , 112)      \
	X( F7 , 113)      \
	X(Gb7 , 114)      \
	X( G7 , 115)      \
	X(Ab7 , 116)      \
	X( A7 , 117)      \
	X(Bb7 , 118)      \
	X( B7 , 119)      \
	X( C8 , 120)      \
	X(Db8 , 121)      \
	X( D8 , 122)      \
	X(Eb8 , 123)      \
	X( E8 , 124)      \
	X( F8 , 125)      \
	X(Gb8 , 126)      \
	X( G8 , 127)

typedef enum {
	#define X(name, v)  LCC_ ## name,
	EACH_LCC(X)
	#undef X
} lowcc_type;

const char *lowcc_name(lowcc_type cc){
	switch (cc){
		#define X(name, v)  case LCC_ ## name: return v == -1 ? "Any" : "Control" # name;
		EACH_LCC(X)
		#undef X
	}
	return "<Unknown>";
}

bool lowcc_fromname(const char *str, lowcc_type *out){
	#define X(name, v)                                         \
		if ((v == -1 && strcmp(str, "Any") == 0) ||            \
			(v != -1 && strcmp(str, "Control" # name) == 0)){  \
			*out = LCC_ ## name;                               \
			return true;                                       \
		}
	EACH_LCC(X)
	#undef X
	return false;
}

void lowcc_midi(lowcc_type cc, int *midi){
	switch (cc){
		#define X(name, v)  case LCC_ ## name: *midi = v; return;
		EACH_LCC(X)
		#undef X
	}
}

bool lowcc_frommidi(int midi, lowcc_type *cc){
	switch (midi){
		#define X(name, v)  case v: *cc = LCC_ ## name; return true;
		EACH_LCC(X)
		#undef X
	}
	return false;
}

typedef enum {
	#define X(name, x, y)  HCC_ ## name,
	EACH_HCC(X)
	#undef X
} highcc_type;

const char *highcc_name(highcc_type cc){
	switch (cc){
		#define X(name, x, y)  case HCC_ ## name: return x == -1 ? "Any" : "Control" # name;
		EACH_HCC(X)
		#undef X
	}
	return "<Unknown>";
}

bool highcc_fromname(const char *str, highcc_type *out){
	#define X(name, x, y)                                      \
		if ((x == -1 && strcmp(str, "Any") == 0) ||            \
			(x != -1 && strcmp(str, "Control" # name) == 0)){  \
			*out = HCC_ ## name;                               \
			return true;                                       \
		}
	EACH_HCC(X)
	#undef X
	return false;
}

void highcc_midi(highcc_type cc, int *midi1, int *midi2){
	switch (cc){
		#define X(name, x, y)  case HCC_ ## name: *midi1 = x; *midi2 = y; return;
		EACH_HCC(X)
		#undef X
	}
}

bool highcc_frommidi(int midi, highcc_type *cc, bool *msb, int *index){
	switch (midi){
		#define X(name, x, y)        \
			case x:                  \
			case y:                  \
				*cc = HCC_ ## name;  \
				*msb = midi == x;    \
				*index = x;          \
				return true;
		EACH_HCC(X)
		#undef X
	}
	return false;
}

typedef enum {
	#define X(name, x, y)  RPN_ ## name,
	EACH_RPN(X)
	#undef X
} rpn_type;

const char *rpn_name(rpn_type rpn){
	switch (rpn){
		#define X(name, x, y)  case RPN_ ## name: return x == -1 ? "Any" : "RPN" # name;
		EACH_RPN(X)
		#undef X
	}
	return "<Unknown>";
}

bool rpn_fromname(const char *str, rpn_type *out){
	#define X(name, x, y)                                  \
		if ((x == -1 && strcmp(str, "Any") == 0) ||        \
			(x != -1 && strcmp(str, "RPN" # name) == 0)){  \
			*out = RPN_ ## name;                           \
			return true;                                   \
		}
	EACH_RPN(X)
	#undef X
	return false;
}

void rpn_midi(rpn_type rpn, int *midi1, int *midi2){
	switch (rpn){
		#define X(name, x, y)  case RPN_ ## name: *midi1 = x; *midi2 = y; return;
		EACH_RPN(X)
		#undef X
	}
}

const char *note_name(int note){
	switch (note){
		#define X(name, v)   case v: return v == -1 ? "Any" : "Note" # name;
		EACH_NOTE(X)
		#undef X
	}
	return "<Unknown>";
}

int note_fromname(const char *str){
	#define X(name, v)                                     \
		if ((v == -1 && strcmp(str, "Any") == 0) ||        \
			(v != -1 && strcmp(str, "Note" # name) == 0))  \
			return v;
	EACH_NOTE(X)
	#undef X
	return -2;
}

typedef enum {
	MA_VAL_NUM    = 1 <<  0,
	MA_VAL_STR    = 1 <<  1,
	MA_VAL_NOTE   = 1 <<  2,
	MA_VAL_LOWCC  = 1 <<  3,
	MA_VAL_HIGHCC = 1 <<  4,
	MA_VAL_RPN    = 1 <<  5,
	MA_RAWDATA    = 1 <<  6,
	MA_CHANNEL    = 1 <<  7,
	MA_NOTE       = 1 <<  8,
	MA_VELOCITY   = 1 <<  9,
	MA_BEND       = 1 << 10,
	MA_PRESSURE   = 1 << 11,
	MA_PATCH      = 1 << 12,
	MA_CONTROL    = 1 << 13,
	MA_VALUE      = 1 << 14,
	MA_RPN        = 1 << 15,
	MA_NRPN       = 1 << 16
} maparg_type;

typedef struct {
	maparg_type type;
	union {
		int num;
		char *str;
		int note;
		lowcc_type lowcc;
		highcc_type highcc;
		rpn_type rpn;
	} val;
} maparg_st, *maparg;

typedef enum {
	MC_PRINT,
	MC_SENDCOPY,
	MC_SENDNOTE,
	MC_SENDBEND,
	MC_SENDNOTEPRESSURE,
	MC_SENDCHANPRESSURE,
	MC_SENDPATCH,
	MC_SENDLOWCC,
	MC_SENDHIGHCC,
	MC_SENDRPN,
	MC_SENDNRPN,
	MC_SENDALLSOUNDOFF,
	MC_SENDALLNOTESOFF,
	MC_SENDRESET
} mapcmd_type;

typedef struct {
	mapcmd_type type;
	int size;
	maparg_st *args;
} mapcmd_st, *mapcmd;

typedef enum {
	MH_NOTE,
	MH_BEND,
	MH_NOTEPRESSURE,
	MH_CHANPRESSURE,
	MH_PATCH,
	MH_LOWCC,
	MH_HIGHCC,
	MH_RPN,
	MH_NRPN,
	MH_ALLSOUNDOFF,
	MH_ALLNOTESOFF,
	MH_RESET,
	MH_ELSE
} maphandler_type;

typedef struct {
	maphandler_type type;
	union {
		struct {
			int channel;
			int note;
			int velocity;
		} note;
		struct {
			int channel;
			int bend;
		} bend;
		struct {
			int channel;
			int note;
			int pressure;
		} notepressure;
		struct {
			int channel;
			int pressure;
		} chanpressure;
		struct {
			int channel;
			int patch;
		} patch;
		struct {
			int channel;
			lowcc_type control;
			int value;
		} lowcc;
		struct {
			int channel;
			highcc_type control;
			int value;
		} highcc;
		struct {
			int channel;
			rpn_type rpn;
			int value;
		} rpn;
		struct {
			int channel;
			int nrpn;
			int value;
		} nrpn;
		struct {
			int channel;
		} allsoundoff;
		struct {
			int channel;
		} allnotesoff;
		struct {
			int channel;
		} reset;
	} u;
	int size;
	mapcmd_st *cmds;
} maphandler_st, *maphandler;

typedef struct {
	int size;
	maphandler_st *handlers;
} mapfile_st, *mapfile;

inline void *m_alloc(size_t size){
	void *p = malloc(size);
	if (p == NULL){
		fprintf(stderr, "Fatal Error: Out of memory!\n");
		exit(1);
	}
	return p;
}

inline void *m_realloc(void *p, size_t size){
	p = realloc(p, size);
	if (p == NULL){
		fprintf(stderr, "Fatal Error: Out of memory!\n");
		exit(1);
	}
	return p;
}

inline void m_free(void *p){
	free(p);
}

char *format(const char *fmt, ...){
	va_list args, args2;
	va_start(args, fmt);
	va_copy(args2, args);
	size_t s = vsnprintf(NULL, 0, fmt, args);
	char *buf = m_alloc(s + 1);
	vsprintf(buf, fmt, args2);
	va_end(args);
	va_end(args2);
	return buf;
}

void midinotify(const MIDINotification *message, void *user){
	const char *msg = "Unknown";
	switch (message->messageID){
		case kMIDIMsgSetupChanged          : msg = "kMIDIMsgSetupChanged";           break;
		case kMIDIMsgObjectAdded           : msg = "kMIDIMsgObjectAdded";            break;
		case kMIDIMsgObjectRemoved         : msg = "kMIDIMsgObjectRemoved";          break;
		case kMIDIMsgPropertyChanged       : msg = "kMIDIMsgPropertyChanged";        break;
		case kMIDIMsgThruConnectionsChanged: msg = "kMIDIMsgThruConnectionsChanged"; break;
		case kMIDIMsgSerialPortOwnerChanged: msg = "kMIDIMsgSerialPortOwnerChanged"; break;
		case kMIDIMsgIOError               : msg = "kMIDIMsgIOError";                break;
	}
	fprintf(stderr, "Notify: %s\n", msg);
}

bool done = true;
pthread_mutex_t done_mutex;
pthread_cond_t done_cond;
void catchdone(int dummy){
	pthread_mutex_lock(&done_mutex);
	done = true;
	pthread_mutex_unlock(&done_mutex);
	pthread_cond_signal(&done_cond);
}

MIDIEndpointRef midiout;
MIDITimeStamp tsnow;

void midisend(int size, const uint8_t *data){
	//printf("send:"); for (int i = 0; i < size; i++) printf(" %02X", data[i]); printf("\n");
	static uint8_t buffer[1000];
	MIDIPacketList *pkl = (MIDIPacketList *)buffer;
	MIDIPacket *pk = MIDIPacketListInit(pkl);
	MIDIPacketListAdd(pkl, sizeof(buffer), pk, tsnow, size, data);
	OSStatus st = MIDIReceived(midiout, pkl);
	if (st != 0)
		fprintf(stderr, "Failed to send MIDI message\n");
}

typedef struct {
	int channel;
	int note;
	int velocity;
	int bend;
	int pressure;
	int patch;
	bool cclow; // is Control a lowcc?
	lowcc_type lowcc;
	highcc_type highcc;
	int value;
	rpn_type rpn;
	int nrpn;
} cmdctx;

void mapcmds_exe(int size, mapcmd_st *cmds, cmdctx ctx, int dsize, const uint8_t *data){
	uint8_t send[10];
	for (int c = 0; c < size; c++){
		mapcmd cmd = &cmds[c];
		switch (cmd->type){
			case MC_PRINT:
				for (int i = 0; i < cmd->size; i++){
					if (i > 0)
						printf(" ");
					maparg ma = &cmd->args[i];
					switch (ma->type){
						case MA_VAL_NUM   : printf("%d", ma->val.num);                 break;
						case MA_VAL_STR   : printf("%s", ma->val.str);                 break;
						case MA_VAL_NOTE  : printf("%s", note_name(ma->val.note));     break;
						case MA_VAL_LOWCC : printf("%s", lowcc_name(ma->val.lowcc));   break;
						case MA_VAL_HIGHCC: printf("%s", highcc_name(ma->val.highcc)); break;
						case MA_VAL_RPN   : printf("%s", rpn_name(ma->val.rpn));       break;
						case MA_RAWDATA:
							printf("[");
							for (int i = 0; i < dsize; i++)
								printf(i == 0 ? "%02X" : " %02X", data[i]);
							printf("]");
							break;
						case MA_CHANNEL   : printf("%d", ctx.channel);                 break;
						case MA_NOTE      : printf("%s", note_name(ctx.note));         break;
						case MA_VELOCITY  : printf("%d", ctx.velocity);                break;
						case MA_BEND      : printf("%d", ctx.bend);                    break;
						case MA_PRESSURE  : printf("%d", ctx.pressure);                break;
						case MA_PATCH     : printf("%d", ctx.patch);                   break;
						case MA_CONTROL:
							printf("%s",
								ctx.cclow ? lowcc_name(ctx.lowcc) : highcc_name(ctx.highcc));
							break;
						case MA_VALUE     : printf("%d", ctx.value);                   break;
						case MA_RPN       : printf("%s", rpn_name(ctx.rpn));           break;
						case MA_NRPN      : printf("%d", ctx.nrpn);                    break;
					}
				}
				printf("\n");
				break;
			case MC_SENDCOPY:
				midisend(dsize, data);
				break;
			case MC_SENDNOTE: {
				int channel = cmd->args[0].type == MA_VAL_NUM ? cmd->args[0].val.num : ctx.channel;
				int note = cmd->args[1].type == MA_VAL_NOTE ? cmd->args[1].val.note : ctx.note;
				int vel = cmd->args[2].type == MA_VAL_NUM ? cmd->args[2].val.num : ctx.velocity;
				send[0] = (vel == 0 ? 0x80 : 0x90) | (channel - 1);
				send[1] = note;
				send[2] = vel;
				midisend(3, send);
			} break;
			case MC_SENDBEND: {
				int channel = cmd->args[0].type == MA_VAL_NUM ? cmd->args[0].val.num : ctx.channel;
				int bend = cmd->args[1].type == MA_VAL_NUM ? cmd->args[1].val.num : ctx.bend;
				send[0] = 0xE0 | (channel - 1);
				send[1] = bend & 0x7F;
				send[2] = (bend >> 7) & 0x7F;
				midisend(3, send);
			} break;
			case MC_SENDNOTEPRESSURE:
				TODO("MC_SENDNOTEPRESSURE");
				break;
			case MC_SENDCHANPRESSURE:
				TODO("MC_SENDCHANPRESSURE");
				break;
			case MC_SENDPATCH: {
				int channel = cmd->args[0].type == MA_VAL_NUM ? cmd->args[0].val.num : ctx.channel;
				int patch = cmd->args[1].type == MA_VAL_NUM ? cmd->args[1].val.num : ctx.patch;
				send[0] = 0xC0 | (channel - 1);
				send[1] = patch;
				midisend(2, send);
			} break;
			case MC_SENDLOWCC: {
				int channel = cmd->args[0].type == MA_VAL_NUM ? cmd->args[0].val.num : ctx.channel;
				int control;
				lowcc_midi(cmd->args[1].type == MA_VAL_LOWCC ? cmd->args[1].val.lowcc : ctx.lowcc,
					&control);
				int value = cmd->args[2].type == MA_VAL_NUM ? cmd->args[2].val.num : ctx.value;
				send[0] = 0xB0 | (channel - 1);
				send[1] = control;
				send[2] = value;
				midisend(3, send);
			} break;
			case MC_SENDHIGHCC: {
				int channel = cmd->args[0].type == MA_VAL_NUM ? cmd->args[0].val.num : ctx.channel;
				int control1, control2;
				highcc_midi(
					cmd->args[1].type == MA_VAL_HIGHCC ? cmd->args[1].val.highcc : ctx.highcc,
					&control1, &control2);
				int value = cmd->args[2].type == MA_VAL_NUM ? cmd->args[2].val.num : ctx.value;
				send[0] = 0xB0 | (channel - 1);
				send[1] = control1;
				send[2] = (value >> 7) & 0x7F;
				if ((value & 0x7F) != 0){
					send[3] = 0xB0 | (channel - 1);
					send[4] = control2;
					send[5] = value & 0x7F;
					midisend(6, send);
				}
				else
					midisend(3, send);
			} break;
			case MC_SENDRPN:
				TODO("MC_SENDRPN");
				break;
			case MC_SENDNRPN:
				TODO("MC_SENDNRPN");
				break;
			case MC_SENDALLSOUNDOFF: {
				int channel = cmd->args[0].type == MA_VAL_NUM ? cmd->args[0].val.num : ctx.channel;
				send[0] = 0xB0 | (channel - 1);
				send[1] = 0x78;
				send[2] = 0x00;
				midisend(3, send);
			} break;
			case MC_SENDALLNOTESOFF: {
				int channel = cmd->args[0].type == MA_VAL_NUM ? cmd->args[0].val.num : ctx.channel;
				send[0] = 0xB0 | (channel - 1);
				send[1] = 0x7B;
				send[2] = 0x00;
				midisend(3, send);
			} break;
			case MC_SENDRESET: {
				int channel = cmd->args[0].type == MA_VAL_NUM ? cmd->args[0].val.num : ctx.channel;
				send[0] = 0xB0 | (channel - 1);
				send[1] = 0x79;
				send[2] = 0x00;
				midisend(3, send);
			} break;
		}
	}
}

void midimsg(int size, mapfile *mfs, maphandler_type type, cmdctx ctx, int dsize,
	const uint8_t *data){
	for (int m = 0; m < size; m++){
		mapfile mf = mfs[m];
		for (int h = 0; h < mf->size; h++){
			maphandler mh = &mf->handlers[h];
			if (mh->type != type)
				continue;
			switch (type){
				case MH_NOTE:
					if ((mh->u.note.channel == -1 ||
							(mh->u.note.channel == -2 && ctx.channel > 0) ||
							mh->u.note.channel == ctx.channel) &&
						(mh->u.note.note == -1 || mh->u.note.note == ctx.note) &&
						(mh->u.note.velocity == -1 ||
							(mh->u.note.velocity == -2 && ctx.velocity > 0) ||
							mh->u.note.velocity == ctx.velocity)){
						mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
						return;
					}
					break;
				case MH_BEND:
					if ((mh->u.bend.channel == -1 ||
							(mh->u.bend.channel == -2 && ctx.channel > 0) ||
							mh->u.bend.channel == ctx.channel) &&
						(mh->u.bend.bend == -1 ||
							(mh->u.bend.bend == -2 && ctx.bend > 0) ||
							mh->u.bend.bend == ctx.bend)){
						mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
						return;
					}
					break;
				case MH_NOTEPRESSURE:
					TODO("MH_NOTEPRESSURE")
					break;
				case MH_CHANPRESSURE:
					TODO("MH_CHANPRESSURE")
					break;
				case MH_PATCH:
					if ((mh->u.patch.channel == -1 ||
							(mh->u.patch.channel == -2 && ctx.channel > 0) ||
							mh->u.patch.channel == ctx.channel) &&
						(mh->u.patch.patch == -1 ||
							(mh->u.patch.patch == -2 && ctx.patch > 0) ||
							mh->u.patch.patch == ctx.patch)){
						mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
						return;
					}
					break;
				case MH_LOWCC:
					if ((mh->u.lowcc.channel == -1 ||
							(mh->u.lowcc.channel == -2 && ctx.channel > 0) ||
							mh->u.lowcc.channel == ctx.channel) &&
						(mh->u.lowcc.control == LCC__Any || mh->u.lowcc.control == ctx.lowcc) &&
						(mh->u.lowcc.value == -1 ||
							(mh->u.lowcc.value == -2 && ctx.value > 0) ||
							mh->u.lowcc.value == ctx.value)){
						mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
						return;
					}
					break;
				case MH_HIGHCC:
					if ((mh->u.highcc.channel == -1 ||
							(mh->u.highcc.channel == -2 && ctx.channel > 0) ||
							mh->u.highcc.channel == ctx.channel) &&
						(mh->u.highcc.control == HCC__Any || mh->u.highcc.control == ctx.highcc) &&
						(mh->u.highcc.value == -1 ||
							(mh->u.highcc.value == -2 && ctx.value > 0) ||
							mh->u.highcc.value == ctx.value)){
						mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
						return;
					}
					break;
				case MH_RPN:
					TODO("MH_RPN")
					break;
				case MH_NRPN:
					TODO("MH_NRPN")
					break;
				case MH_ALLSOUNDOFF:
					if ((mh->u.allsoundoff.channel == -1 ||
							(mh->u.allsoundoff.channel == -2 && ctx.channel > 0) ||
							mh->u.allsoundoff.channel == ctx.channel)){
						mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
						return;
					}
					break;
				case MH_ALLNOTESOFF:
					if ((mh->u.allnotesoff.channel == -1 ||
							(mh->u.allnotesoff.channel == -2 && ctx.channel > 0) ||
							mh->u.allnotesoff.channel == ctx.channel)){
						mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
						return;
					}
					break;
				case MH_RESET:
					if ((mh->u.reset.channel == -1 ||
							(mh->u.reset.channel == -2 && ctx.channel > 0) ||
							mh->u.reset.channel == ctx.channel)){
						mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
						return;
					}
					break;
				case MH_ELSE:
					mapcmds_exe(mh->size, mh->cmds, ctx, dsize, data);
					return;
			}
		}
	}
	// nothing got it, so see if OnElse should get it
	if (type != MH_ELSE)
		midimsg(size, mfs, MH_ELSE, (cmdctx){0}, dsize, data);
}

typedef struct {
	mapfile *mfs;
	int size;
	int cc[32];
} midictx_st, *midictx;

void midiread(const MIDIPacketList *pkl, midictx mctx, void *dummy){
	const MIDIPacket *p = &pkl->packet[0];
	int mfs_size = mctx->size;
	mapfile *mfs = mctx->mfs;
	uint8_t delse[256];
	for (int i = 0; i < pkl->numPackets; i++){
		int mi = 0;
		int ielse = 0;
		tsnow = p->timeStamp;
		#define CHECK_ELSE()  do{                                                \
				if (ielse > 0){                                                  \
					midimsg(mfs_size, mfs, MH_ELSE, (cmdctx){0}, ielse, delse);  \
					ielse = 0;                                                   \
				}                                                                \
			} while (false)
		while (mi < p->length){
			switch (p->data[mi] & 0xF0){
				case 0x80: { // Note Off: Note/Velocity
					CHECK_ELSE();
					if (mi + 3 > p->length){
						mi += 3;
						break;
					}
					// report note off as note on with zero velocity
					midimsg(mfs_size, mfs, MH_NOTE, (cmdctx){
						.channel = (p->data[mi] & 0x0F) + 1,
						.note = p->data[mi + 1],
						.velocity = 0
					}, 3, &p->data[mi]);
					mi += 3;
				} break;
				case 0x90: { // Note On: Note/Velocity
					CHECK_ELSE();
					if (mi + 3 > p->length){
						mi += 3;
						break;
					}
					midimsg(mfs_size, mfs, MH_NOTE, (cmdctx){
						.channel = (p->data[mi] & 0x0F) + 1,
						.note = p->data[mi + 1],
						.velocity = p->data[mi + 2]
					}, 3, &p->data[mi]);
					mi += 3;
				} break;
				case 0xA0: { // Note Pressure: Note/Pressure
					CHECK_ELSE();
					if (mi + 3 > p->length){
						mi += 3;
						break;
					}
					midimsg(mfs_size, mfs, MH_NOTEPRESSURE, (cmdctx){
						.channel = (p->data[mi] & 0x0F) + 1,
						.note = p->data[mi + 1],
						.pressure = p->data[mi + 2]
					}, 3, &p->data[mi]);
					mi += 3;
				} break;
				case 0xB0: { // Control Change: Control/Value
					CHECK_ELSE();
					if (mi + 3 > p->length){
						mi += 3;
						break;
					}
					lowcc_type lowcc;
					highcc_type highcc;
					bool msb;
					int index;
					if (p->data[mi + 1] == 0x78){ // All Sound Off
						midimsg(mfs_size, mfs, MH_ALLSOUNDOFF, (cmdctx){
							.channel = (p->data[mi] & 0x0F) + 1
						}, 3, &p->data[mi]);
					}
					else if (p->data[mi + 1] == 0x7B){ // All Notes Off
						midimsg(mfs_size, mfs, MH_ALLNOTESOFF, (cmdctx){
							.channel = (p->data[mi] & 0x0F) + 1
						}, 3, &p->data[mi]);
					}
					else if (p->data[mi + 1] == 0x79){ // Reset
						midimsg(mfs_size, mfs, MH_RESET, (cmdctx){
							.channel = (p->data[mi] & 0x0F) + 1
						}, 3, &p->data[mi]);
					}
					else if (lowcc_frommidi(p->data[mi + 1], &lowcc)){
						// found a lowcc
						midimsg(mfs_size, mfs, MH_LOWCC, (cmdctx){
							.channel = (p->data[mi] & 0x0F) + 1,
							.cclow = true,
							.lowcc = lowcc,
							.value = p->data[mi + 2]
						}, 3, &p->data[mi]);
					}
					else if (highcc_frommidi(p->data[mi + 1], &highcc, &msb, &index)){
						// found a highcc
						if (msb)
							mctx->cc[index] = p->data[mi + 2] << 7;
						else
							mctx->cc[index] = (mctx->cc[index] & 0x3F8) | p->data[mi + 2];
						midimsg(mfs_size, mfs, MH_HIGHCC, (cmdctx){
							.channel = (p->data[mi] & 0x0F) + 1,
							.cclow = false,
							.highcc = highcc,
							.value = mctx->cc[index]
						}, 3, &p->data[mi]);
					}
					mi += 3;
				} break;
				case 0xC0: { // Program Change: Patch
					CHECK_ELSE();
					if (mi + 2 > p->length){
						mi += 2;
						break;
					}
					midimsg(mfs_size, mfs, MH_PATCH, (cmdctx){
						.channel = (p->data[mi] & 0x0F) + 1,
						.patch = p->data[mi + 1]
					}, 2, &p->data[mi]);
					mi += 2;
				} break;
				case 0xD0: { // Channel Pressure: Pressure
					CHECK_ELSE();
					if (mi + 2 > p->length){
						mi += 2;
						break;
					}
					midimsg(mfs_size, mfs, MH_CHANPRESSURE, (cmdctx){
						.channel = (p->data[mi] & 0x0F) + 1,
						.pressure = p->data[mi + 1]
					}, 2, &p->data[mi]);
					mi += 2;
				} break;
				case 0xE0: { // Pitch Bend: LSB/MSB
					CHECK_ELSE();
					if (mi + 3 > p->length){
						mi += 3;
						break;
					}
					midimsg(mfs_size, mfs, MH_BEND, (cmdctx){
						.channel = (p->data[mi] & 0x0F) + 1,
						.bend = (((int)p->data[mi + 2])) << 7 | ((int)p->data[mi + 1])
					}, 3, &p->data[mi]);
					mi += 3;
				} break;
				default:
					if (ielse < 256)
						delse[ielse++] = p->data[mi++];
					break;
			}
		}
		CHECK_ELSE();
		p = MIDIPacketNext(p);
	}
	#undef CHECK_ELSE
}

inline bool isWhite(char ch){
	return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
}

inline bool isNum(char ch){
	return ch >= '0' && ch <= '9';
}

bool parseint(const char *str, int *out){
	int i = 0;
	int num = 0;
	bool nonwhite = false;
	int digits = 0;
	while (str[i]){
		char ch = str[i++];
		if (!nonwhite){
			if (isWhite(ch))
				continue;
			nonwhite = true;
		}
		if (!isNum(ch))
			return false;
		num = (num * 10) + (ch - '0');
		digits++;
		if (digits > 6)
			return false;
	}
	if (!nonwhite)
		return false;
	*out = num;
	return true;
}

int anyint(const char *str){
	if (strcmp(str, "Any") == 0)
		return -1;
	if (strcmp(str, "Positive") == 0)
		return -2;
	int ret;
	if (parseint(str, &ret))
		return ret;
	return -3;
}

char *trim(char *line){
	int s = 0;
	while (line[s] && isWhite(line[s])){
		if (line[s] == '#'){
			line[0] = 0;
			return line;
		}
		s++;
	}
	if (line[s] == 0){
		line[0] = 0;
		return line;
	}
	int len = 0;
	int e = s;
	while (line[e] && line[e] != '#'){
		if (!isWhite(line[e]))
			len = e - s + 1;
		e++;
	}
	line[s + len] = 0;
	return &line[s];
}

int split(char *line, char **comp){
	int i = 0;
	bool marking = false;
	bool inside_str = false;
	int next = 0;
	while (line[i] && next < 10){
		if (marking){
			if (inside_str && line[i] == '"'){
				i++;
				marking = false;
				line[i] = 0;
			}
			else if (!inside_str && isWhite(line[i])){
				marking = false;
				line[i] = 0;
			}
		}
		else{
			if (!isWhite(line[i])){
				marking = true;
				inside_str = line[i] == '"';
				comp[next++] = &line[i];
			}
			else
				line[i] = 0;
		}
		i++;
	}
	return next;
}

bool maparg_parse(const char *str, int allow_mask, maparg_st *ma){
	if (allow_mask & MA_VAL_NUM){
		int ret;
		if (parseint(str, &ret)){
			ma->type = MA_VAL_NUM;
			ma->val.num = ret;
			return true;
		}
	}
	if (allow_mask & MA_VAL_STR){
		if (str[0] == '"'){
			int len = strlen(str);
			if (str[len - 1] == '"'){
				ma->type = MA_VAL_STR;
				ma->val.str = format("%.*s", len - 2, &str[1]);
				return true;
			}
		}
	}
	if (allow_mask & MA_VAL_NOTE){
		int note = note_fromname(str);
		if (note >= 0){
			ma->type = MA_VAL_NOTE;
			ma->val.note = note;
			return true;
		}
	}
	if (allow_mask & MA_VAL_LOWCC){
		lowcc_type lowcc;
		if (lowcc_fromname(str, &lowcc) && lowcc != LCC__Any){
			ma->type = MA_VAL_LOWCC;
			ma->val.lowcc = lowcc;
			return true;
		}
	}
	if (allow_mask & MA_VAL_HIGHCC){
		highcc_type highcc;
		if (highcc_fromname(str, &highcc) && highcc != HCC__Any){
			ma->type = MA_VAL_HIGHCC;
			ma->val.highcc = highcc;
			return true;
		}
	}
	if (allow_mask & MA_VAL_RPN){
		rpn_type rpn;
		if (rpn_fromname(str, &rpn) && rpn != RPN__Any){
			ma->type = MA_VAL_RPN;
			ma->val.rpn = rpn;
			return true;
		}
	}
	#define LITERAL(mask, litstr)           \
		if (allow_mask & mask){             \
			if (strcmp(str, litstr) == 0){  \
				ma->type = mask;            \
				return true;                \
			}                               \
		}
	LITERAL(MA_RAWDATA , "RawData" )
	LITERAL(MA_CHANNEL , "Channel" )
	LITERAL(MA_NOTE    , "Note"    )
	LITERAL(MA_VELOCITY, "Velocity")
	LITERAL(MA_BEND    , "Bend"    )
	LITERAL(MA_PRESSURE, "Pressure")
	LITERAL(MA_PATCH   , "Patch"   )
	LITERAL(MA_CONTROL , "Control" )
	LITERAL(MA_VALUE   , "Value"   )
	LITERAL(MA_RPN     , "RPN"     )
	LITERAL(MA_NRPN    , "NRPN"    )
	#undef LITERAL
	return false;
}

void maphandler_parse(char *const *comp, int cs, bool *valid, bool *found, maphandler_st *mh){
	*valid = false;
	*found = true;
	if (cs <= 0){
		*valid = true;
		*found = false;
		return;
	}

	maphandler_type mht = MH_NOTE;
	bool mhtv = false;
	if      (strcmp(comp[0], "OnNote"        ) == 0){ mhtv = true; mht = MH_NOTE        ; }
	else if (strcmp(comp[0], "OnBend"        ) == 0){ mhtv = true; mht = MH_BEND        ; }
	else if (strcmp(comp[0], "OnNotePressure") == 0){ mhtv = true; mht = MH_NOTEPRESSURE; }
	else if (strcmp(comp[0], "OnChanPressure") == 0){ mhtv = true; mht = MH_CHANPRESSURE; }
	else if (strcmp(comp[0], "OnPatch"       ) == 0){ mhtv = true; mht = MH_PATCH       ; }
	else if (strcmp(comp[0], "OnLowCC"       ) == 0){ mhtv = true; mht = MH_LOWCC       ; }
	else if (strcmp(comp[0], "OnHighCC"      ) == 0){ mhtv = true; mht = MH_HIGHCC      ; }
	else if (strcmp(comp[0], "OnRPN"         ) == 0){ mhtv = true; mht = MH_RPN         ; }
	else if (strcmp(comp[0], "OnNRPN"        ) == 0){ mhtv = true; mht = MH_NRPN        ; }
	else if (strcmp(comp[0], "OnAllSoundOff" ) == 0){ mhtv = true; mht = MH_ALLSOUNDOFF ; }
	else if (strcmp(comp[0], "OnAllNotesOff" ) == 0){ mhtv = true; mht = MH_ALLNOTESOFF ; }
	else if (strcmp(comp[0], "OnReset"       ) == 0){ mhtv = true; mht = MH_RESET       ; }
	else if (strcmp(comp[0], "OnElse"        ) == 0){ mhtv = true; mht = MH_ELSE        ; }
	if (!mhtv){
		fprintf(stderr, "Invalid event handler: %s\n", comp[0]);
		return;
	}

	switch (mht){
		case MH_NOTE: {
			if (cs != 4){
				fprintf(stderr, "Invalid format for OnNote handler\n");
				return;
			}
			int channel = anyint(comp[1]);
			if (channel < -2){
				fprintf(stderr, "Invalid channel for OnNote handler: %s\n", comp[1]);
				return;
			}
			int note = note_fromname(comp[2]);
			if (note < -1){
				fprintf(stderr, "Invalid note for OnNote handler: %s\n", comp[2]);
				return;
			}
			int velocity = anyint(comp[3]);
			if (velocity < -2){
				fprintf(stderr, "Invalid velocity for OnNote handler: %s\n", comp[3]);
				return;
			}
			*valid = true;
			mh->type = MH_NOTE;
			mh->u.note.channel = channel;
			mh->u.note.note = note;
			mh->u.note.velocity = velocity;
		} return;
		case MH_BEND: {
			if (cs != 3){
				fprintf(stderr, "Invalid format for OnBend handler\n");
				return;
			}
			int channel = anyint(comp[1]);
			if (channel < -2){
				fprintf(stderr, "Invalid channel for OnBend handler: %s\n", comp[1]);
				return;
			}
			int bend = anyint(comp[2]);
			if (bend < -2){
				fprintf(stderr, "Invalid value for OnBend handler: %s\n", comp[2]);
				return;
			}
			*valid = true;
			mh->type = MH_BEND;
			mh->u.bend.channel = channel;
			mh->u.bend.bend = bend;
		} return;
		case MH_NOTEPRESSURE:
			TODO("MH_NOTEPRESSURE");
			break;
		case MH_CHANPRESSURE:
			TODO("MH_CHANPRESSURE");
			break;
		case MH_PATCH: {
			if (cs != 3){
				fprintf(stderr, "Invalid format for OnPatch handler\n");
				return;
			}
			int channel = anyint(comp[1]);
			if (channel < -2){
				fprintf(stderr, "Invalid channel for OnPatch handler: %s\n", comp[1]);
				return;
			}
			int patch = anyint(comp[2]);
			if (patch < -2){
				fprintf(stderr, "Invalid value for OnPatch handler: %s\n", comp[2]);
				return;
			}
			*valid = true;
			mh->type = MH_PATCH;
			mh->u.patch.channel = channel;
			mh->u.patch.patch = patch;
		} return;
		case MH_LOWCC: {
			if (cs != 4){
				fprintf(stderr, "Invalid format for OnLowCC handler\n");
				return;
			}
			int channel = anyint(comp[1]);
			if (channel < -2){
				fprintf(stderr, "Invalid channel for OnLowCC handler: %s\n", comp[1]);
				return;
			}
			lowcc_type control;
			if (!lowcc_fromname(comp[2], &control)){
				fprintf(stderr, "Invalid control for OnLowCC handler: %s\n", comp[2]);
				return;
			}
			int value = anyint(comp[3]);
			if (value < -2){
				fprintf(stderr, "Invalid value for OnLowCC handler: %s\n", comp[3]);
				return;
			}
			*valid = true;
			mh->type = MH_LOWCC;
			mh->u.lowcc.channel = channel;
			mh->u.lowcc.control = control;
			mh->u.lowcc.value = value;
		} return;
		case MH_HIGHCC: {
			if (cs != 4){
				fprintf(stderr, "Invalid format for OnHighCC handler\n");
				return;
			}
			int channel = anyint(comp[1]);
			if (channel < -2){
				fprintf(stderr, "Invalid channel for OnHighCC handler: %s\n", comp[1]);
				return;
			}
			highcc_type control;
			if (!highcc_fromname(comp[2], &control)){
				fprintf(stderr, "Invalid control for OnHighCC handler: %s\n", comp[2]);
				return;
			}
			int value = anyint(comp[3]);
			if (value < -2){
				fprintf(stderr, "Invalid value for OnHighCC handler: %s\n", comp[3]);
				return;
			}
			*valid = true;
			mh->type = MH_HIGHCC;
			mh->u.highcc.channel = channel;
			mh->u.highcc.control = control;
			mh->u.highcc.value = value;
		} return;
		case MH_RPN:
			TODO("MH_RPN");
			break;
		case MH_NRPN:
			TODO("MH_NRPN");
			break;
		case MH_ALLSOUNDOFF: {
			if (cs != 2){
				fprintf(stderr, "Invalid format for OnAllSoundOff handler\n");
				return;
			}
			int channel = anyint(comp[1]);
			if (channel < -2){
				fprintf(stderr, "Invalid channel for OnAllSoundOff handler: %s\n", comp[1]);
				return;
			}
			*valid = true;
			mh->type = MH_ALLSOUNDOFF;
			mh->u.allsoundoff.channel = channel;
		} return;
		case MH_ALLNOTESOFF: {
			if (cs != 2){
				fprintf(stderr, "Invalid format for OnAllNotesOff handler\n");
				return;
			}
			int channel = anyint(comp[1]);
			if (channel < -2){
				fprintf(stderr, "Invalid channel for OnAllNotesOff handler: %s\n", comp[1]);
				return;
			}
			*valid = true;
			mh->type = MH_ALLNOTESOFF;
			mh->u.allnotesoff.channel = channel;
		} return;
		case MH_RESET: {
			if (cs != 2){
				fprintf(stderr, "Invalid format for OnReset handler\n");
				return;
			}
			int channel = anyint(comp[1]);
			if (channel < -2){
				fprintf(stderr, "Invalid channel for OnReset handler: %s\n", comp[1]);
				return;
			}
			*valid = true;
			mh->type = MH_RESET;
			mh->u.reset.channel = channel;
		} return;
		case MH_ELSE:
			if (cs != 1){
				fprintf(stderr, "Invalid format for OnElse handler\n");
				return;
			}
			*valid = true;
			mh->type = MH_ELSE;
			return;
	}
}

void mapcmd_parse(maphandler_type mht, char *const *comp, int cs, bool *valid, bool *isend,
	bool *found, mapcmd_st *mc){
	*valid = *isend = false;
	*found = true;
	if (cs <= 0){
		*valid = true;
		*found = false;
		return;
	}
	else if (cs == 1 && strcmp(comp[0], "End") == 0){
		*valid = true;
		*isend = true;
		*found = false;
		return;
	}

	mapcmd_type mct = MC_PRINT;
	bool mctv = false;
	if      (strcmp(comp[0], "Print"           ) == 0){ mctv = true; mct = MC_PRINT           ; }
	else if (strcmp(comp[0], "SendCopy"        ) == 0){ mctv = true; mct = MC_SENDCOPY        ; }
	else if (strcmp(comp[0], "SendNote"        ) == 0){ mctv = true; mct = MC_SENDNOTE        ; }
	else if (strcmp(comp[0], "SendBend"        ) == 0){ mctv = true; mct = MC_SENDBEND        ; }
	else if (strcmp(comp[0], "SendNotePressure") == 0){ mctv = true; mct = MC_SENDNOTEPRESSURE; }
	else if (strcmp(comp[0], "SendChanPressure") == 0){ mctv = true; mct = MC_SENDCHANPRESSURE; }
	else if (strcmp(comp[0], "SendPatch"       ) == 0){ mctv = true; mct = MC_SENDPATCH       ; }
	else if (strcmp(comp[0], "SendLowCC"       ) == 0){ mctv = true; mct = MC_SENDLOWCC       ; }
	else if (strcmp(comp[0], "SendHighCC"      ) == 0){ mctv = true; mct = MC_SENDHIGHCC      ; }
	else if (strcmp(comp[0], "SendRPN"         ) == 0){ mctv = true; mct = MC_SENDRPN         ; }
	else if (strcmp(comp[0], "SendNRPN"        ) == 0){ mctv = true; mct = MC_SENDNRPN        ; }
	else if (strcmp(comp[0], "SendAllSoundOff" ) == 0){ mctv = true; mct = MC_SENDALLSOUNDOFF ; }
	else if (strcmp(comp[0], "SendAllNotesOff" ) == 0){ mctv = true; mct = MC_SENDALLNOTESOFF ; }
	else if (strcmp(comp[0], "SendReset"       ) == 0){ mctv = true; mct = MC_SENDRESET       ; }
	if (!mctv){
		fprintf(stderr, "Invalid command: %s\n", comp[0]);
		return;
	}

	int args_size = 0;
	maparg_st *args = NULL;

	int mht_mask = 0;
	switch (mht){
		case MH_NOTE        : mht_mask = MA_CHANNEL | MA_NOTE | MA_VELOCITY; break;
		case MH_BEND        : mht_mask = MA_CHANNEL | MA_BEND              ; break;
		case MH_NOTEPRESSURE: mht_mask = MA_CHANNEL | MA_NOTE | MA_PRESSURE; break;
		case MH_CHANPRESSURE: mht_mask = MA_CHANNEL | MA_PRESSURE          ; break;
		case MH_PATCH       : mht_mask = MA_CHANNEL | MA_PATCH             ; break;
		case MH_LOWCC       : mht_mask = MA_CHANNEL | MA_CONTROL | MA_VALUE; break;
		case MH_HIGHCC      : mht_mask = MA_CHANNEL | MA_CONTROL | MA_VALUE; break;
		case MH_RPN         : mht_mask = MA_CHANNEL | MA_RPN | MA_VALUE    ; break;
		case MH_NRPN        : mht_mask = MA_CHANNEL | MA_NRPN | MA_VALUE   ; break;
		case MH_ALLSOUNDOFF : mht_mask = MA_CHANNEL                        ; break;
		case MH_ALLNOTESOFF : mht_mask = MA_CHANNEL                        ; break;
		case MH_RESET       : mht_mask = MA_CHANNEL                        ; break;
		case MH_ELSE        : mht_mask = 0                                 ; break;
	}

	#define ADD_ARG(str, allow_mask)  do{                                        \
			maparg_st ma;                                                        \
			if (!maparg_parse(str, (allow_mask) & mht_mask, &ma)){               \
				fprintf(stderr, "Invalid argument for %s: %s\n", comp[0], str);  \
				goto fail;                                                       \
			}                                                                    \
			args_size++;                                                         \
			args = m_realloc(args, sizeof(maparg_st) * args_size);               \
			args[args_size - 1] = ma;                                            \
		} while (false)

	#define CHECK_RANGE(min, max)  do{                                                      \
			if (args[args_size - 1].type == MA_VAL_NUM &&                                   \
				(args[args_size - 1].val.num < min || args[args_size - 1].val.num > max)){  \
				fprintf(stderr, "Number (%d) out of range (%d-%d)\n",                       \
					args[args_size - 1].val.num, min, max);                                 \
				goto fail;                                                                  \
			}                                                                               \
		} while (false)

	#define DONE()  do {           \
			mc->type = mct;        \
			mc->size = args_size;  \
			mc->args = args;       \
			*valid = true;         \
			return;                \
		} while (false)

	switch (mct){
		case MC_PRINT: {
			int mask = mht_mask | MA_VAL_NUM | MA_VAL_STR | MA_VAL_NOTE | MA_VAL_LOWCC |
				MA_VAL_HIGHCC | MA_VAL_RPN | MA_RAWDATA;
			mht_mask = mask;
			for (int i = 1; i < cs; i++)
				ADD_ARG(comp[i], mask);
			DONE();
		};
		case MC_SENDCOPY:
			if (cs != 1){
				fprintf(stderr, "Invalid format for SendCopy command\n");
				return;
			}
			DONE();
		case MC_SENDNOTE:
			if (cs != 4){
				fprintf(stderr, "Invalid format for SendNote command\n");
				return;
			}
			mht_mask |= MA_VAL_NUM | MA_VAL_NOTE;
			ADD_ARG(comp[1], MA_VAL_NUM | MA_CHANNEL);
			CHECK_RANGE(1, 16);
			ADD_ARG(comp[2], MA_VAL_NOTE | MA_NOTE);
			ADD_ARG(comp[3], MA_VAL_NUM | MA_VELOCITY);
			CHECK_RANGE(0, 127);
			DONE();
		case MC_SENDBEND:
			if (cs != 3){
				fprintf(stderr, "Invalid format for SendBend command\n");
				return;
			}
			mht_mask |= MA_VAL_NUM;
			ADD_ARG(comp[1], MA_VAL_NUM | MA_CHANNEL);
			CHECK_RANGE(1, 16);
			ADD_ARG(comp[2], MA_VAL_NUM | MA_BEND);
			CHECK_RANGE(0, 16383);
			DONE();
		case MC_SENDNOTEPRESSURE:
			TODO("MC_SENDNOTEPRESSURE");
			break;
		case MC_SENDCHANPRESSURE:
			TODO("MC_SENDCHANPRESSURE");
			break;
		case MC_SENDPATCH:
			if (cs != 3){
				fprintf(stderr, "Invalid format for SendPatch command\n");
				return;
			}
			mht_mask |= MA_VAL_NUM;
			ADD_ARG(comp[1], MA_VAL_NUM | MA_CHANNEL);
			CHECK_RANGE(1, 16);
			ADD_ARG(comp[2], MA_VAL_NUM | MA_PATCH);
			CHECK_RANGE(0, 127);
			DONE();
		case MC_SENDLOWCC:
			if (cs != 4){
				fprintf(stderr, "Invalid format for SendLowCC command\n");
				return;
			}
			mht_mask |= MA_VAL_NUM | MA_VAL_LOWCC;
			ADD_ARG(comp[1], MA_VAL_NUM | MA_CHANNEL);
			CHECK_RANGE(1, 16);
			ADD_ARG(comp[2], MA_VAL_LOWCC | MA_CONTROL);
			ADD_ARG(comp[3], MA_VAL_NUM | MA_VALUE);
			CHECK_RANGE(0, 127);
			DONE();
		case MC_SENDHIGHCC:
			if (cs != 4){
				fprintf(stderr, "Invalid format for SendHighCC command\n");
				return;
			}
			mht_mask |= MA_VAL_NUM | MA_VAL_HIGHCC;
			ADD_ARG(comp[1], MA_VAL_NUM | MA_CHANNEL);
			CHECK_RANGE(1, 16);
			ADD_ARG(comp[2], MA_VAL_HIGHCC | MA_CONTROL);
			ADD_ARG(comp[3], MA_VAL_NUM | MA_VALUE);
			CHECK_RANGE(0, 16383);
			DONE();
		case MC_SENDRPN:
			TODO("MC_SENDRPN");
			break;
		case MC_SENDNRPN:
			TODO("MC_SENDNRPN");
			break;
		case MC_SENDALLSOUNDOFF:
			if (cs != 2){
				fprintf(stderr, "Invalid format for SendAllSoundOff command\n");
				return;
			}
			mht_mask |= MA_VAL_NUM;
			ADD_ARG(comp[1], MA_VAL_NUM | MA_CHANNEL);
			CHECK_RANGE(1, 16);
			DONE();
		case MC_SENDALLNOTESOFF:
			if (cs != 2){
				fprintf(stderr, "Invalid format for SendAllNotesOff command\n");
				return;
			}
			mht_mask |= MA_VAL_NUM;
			ADD_ARG(comp[1], MA_VAL_NUM | MA_CHANNEL);
			CHECK_RANGE(1, 16);
			DONE();
		case MC_SENDRESET:
			if (cs != 2){
				fprintf(stderr, "Invalid format for SendReset command\n");
				return;
			}
			mht_mask |= MA_VAL_NUM;
			ADD_ARG(comp[1], MA_VAL_NUM | MA_CHANNEL);
			CHECK_RANGE(1, 16);
			DONE();
	}
	fail:
	for (int i = 0; i < args_size; i++){
		if (args[i].type == MA_VAL_STR)
			free(args[i].val.str);
	}
	free(args);
	#undef TODO
	#undef ADD_ARG
	#undef CHECK_RANGE
	#undef DONE
}

void mapfile_free(mapfile mf){
	for (int i = 0; i < mf->size; i++){
		for (int j = 0; j < mf->handlers[i].size; j++){
			for (int k = 0; k < mf->handlers[i].cmds[j].size; k++){
				maparg arg = &mf->handlers[i].cmds[j].args[k];
				if (arg->type == MA_VAL_STR)
					free(arg->val.str);
			}
			free(mf->handlers[i].cmds[j].args);
		}
		free(mf->handlers[i].cmds);
	}
	free(mf);
}

mapfile mapfile_parse(const char *file){
	FILE *fp = fopen(file, "r");
	if (fp == NULL){
		fprintf(stderr, "Failed to open map file: %s\n", file);
		return NULL;
	}

	mapfile mf = m_alloc(sizeof(mapfile_st));
	mf->size = 0;
	mf->handlers = NULL;
	maphandler mh;
	enum {
		ST_START,
		ST_CMDS
	} state = ST_START;
	while (!feof(fp)){
		char line[2000];
		char *comp[11];
		line[0] = 0;
		fgets(line, sizeof(line), fp);
		switch (state){
			case ST_START: {
				bool valid, found;
				maphandler_st mhs;
				maphandler_parse(comp, split(trim(line), comp), &valid, &found, &mhs);
				if (!valid)
					goto invalid;
				if (found){
					mf->size++;
					mf->handlers = m_realloc(mf->handlers, sizeof(maphandler_st) * mf->size);
					mf->handlers[mf->size - 1] = mhs;
					mh = &mf->handlers[mf->size - 1];
					mh->size = 0;
					mh->cmds = NULL;
					state = ST_CMDS;
				}
			} break;
			case ST_CMDS: {
				bool valid, isend, found;
				mapcmd_st mc;
				mapcmd_parse(mh->type, comp, split(trim(line), comp), &valid, &isend, &found, &mc);
				if (!valid)
					goto invalid;
				if (isend)
					state = ST_START;
				else if (found){
					mh->size++;
					mh->cmds = m_realloc(mh->cmds, sizeof(mapcmd_st) * mh->size);
					mh->cmds[mh->size - 1] = mc;
				}
			} break;
		}
	}
	if (state == ST_START){
		fclose(fp);
		return mf;
	}
	fprintf(stderr, "Missing `End` of handler\n");
	invalid:
	mapfile_free(mf);
	fclose(fp);
	return NULL;
}

int main(int argc, char **argv){
	int result = 0;
	bool init_midi = false;
	bool init_out = false;
	#define MAX_SOURCES 100
	int srcs_size = 0;
	struct {
		MIDIEndpointRef ep;
		const char *name;
		int i;
		int size;
		mapfile *mfs;
		bool opened;
		MIDIPortRef pref;
		midictx_st mctx;
	} srcs[MAX_SOURCES];

	// print version and copyright
	printf(
		"midimap 1.0\n"
		"(c) Copyright 2017, Sean Connelly (@voidqk), http://syntheti.cc\n"
		"MIT License\n"
		"Project Home: https://github.com/voidqk/midimap\n");

	// look for version
	if (argc == 2 && (
		strcmp(argv[1], "version") == 0 ||
		strcmp(argv[1], "-version") == 0 ||
		strcmp(argv[1], "--version") == 0 ||
		strcmp(argv[1], "-v") == 0))
		return 0; // already printed, so just exit immediately
	printf("\n");

	bool has_help = argc >= 2 && (
		strcmp(argv[1], "help") == 0 ||
		strcmp(argv[1], "-help") == 0 ||
		strcmp(argv[1], "--help") == 0 ||
		strcmp(argv[1], "-h") == 0);

	// input help
	if (has_help && argc >= 3 && strcmp(argv[2], "input") == 0){
		printf(
			"Usage:\n"
			"  midimap [-m \"Input Device\" <mapfile>]+\n"
			"\n"
			"Input Devices:\n"
			"  The program will always list out the available input devices.  For example:\n"
			"    Source 1: \"Keyboard A\"\n"
			"    Source 2: \"Keyboard B\"\n"
			"    Source 3: No Name Available\n"
			"    Source 4: \"Pads\"\n"
			"    Source 5: \"Pads\"\n"
			"\n"
			"  Sources can be specified using the name:\n"
			"    # selects the source named \"Keyboard A\"\n"
			"    midimap -m \"Keyboard A\" <mapfile>\n"
			"  Or the source index:\n"
			"    # selects source index 5\n"
			"    midimap -m 5 <mapfile>\n"
			"\n"
			"  For more information on how the mapfile works, run:\n"
			"    midimap --help mapfile\n"
		);
		return 0;
	}

	// mapfile help
	if (has_help && argc >= 3 && strcmp(argv[2], "mapfile") == 0){
		printf(
			"Usage:\n"
			"  midimap [-m \"Input Device\" <mapfile>]+\n"
			"\n"
			"Map Files:\n"
			"  Map files consist of a list of event handlers.  If the handler's criteria\n"
			"  matches the message, the instructions in the handler are executed, and no\n"
			"  further handlers are executed.\n"
			"\n"
			"    OnNote 1 NoteGb3 Any\n"
			"      # Change the Gb3 to a C4\n"
			"      Print \"Received:\" Channel Note Velocity\n"
			"      SendNote 16 NoteC4 Velocity\n"
			"    End\n"
			"\n"
			"  For this example, if the input device sends a Gb3 message at any velocity in\n"
			"  channel 1, the program will print the message, and send a C4 instead on\n"
			"  channel 16.\n"
			"\n"
			"  The first line is what message to intercept, and the matching criteria\n"
			"  for the message.  Criteria can be a literal value, `Any` which matches\n"
			"  anything, or `Positive` for a number greater than zero.  Inside the handler,\n"
			"  the instructions are executed in order using raw values (\"Received:\", 16,\n"
			"  NoteC4) or values dependant on the original message (Channel, Note,\n"
			"  Velocity).\n"
			"\n"
			"  Any line that begins with a `#` is ignored and considered a comment.\n"
			"\n"
			"  All event handlers end with `End`.\n"
			"\n"
			"  Event Handlers:\n"
			"    OnNote         <Channel> <Note> <Velocity>  Note is hit or released\n"
			"    OnBend         <Channel> <Bend>             Pitch bend for entire channel\n"
			"    OnNotePressure <Channel> <Note> <Pressure>  Aftertouch applied to note\n"
			"    OnChanPressure <Channel> <Pressure>         Aftertouch for entire channel\n"
			"    OnPatch        <Channel> <Patch>            Program change patch\n"
			"    OnLowCC        <Channel> <Control> <Value>  Low-res control change\n"
			"    OnHighCC       <Channel> <Control> <Value>  High-res control change\n"
			"    OnRPN          <Channel> <RPN> <Value>      Registered device parameter\n"
			"    OnNRPN         <Channel> <NRPN> <Value>     Custom device parameter\n"
			"    OnAllSoundOff  <Channel>                    All Sound Off message\n"
			"    OnAllNotesOff  <Channel>                    All Notes Off message\n"
			"    OnReset        <Channel>                    Reset All Controllers message\n"
			"    OnElse                                      Messages not matched\n"
			"\n"
			"  Parameters:\n"
			"    Channel   MIDI Channel (1-16)\n"
			"    Note      Note value (see details below)\n"
			"    Velocity  How hard the note was hit (0-127) Use 0 for note off\n"
			"    Bend      Amount to bend (0-16383, center at 8192)\n"
			"    Pressure  Aftertouch intensity (0-127)\n"
			"    Patch     Patch being selected (0-127)\n"
			"    Control   Control being modified (see table below)\n"
			"    Value     Value for the control (LowCC: 0-127, HighCC/RPN/NRPN: 0-16383)\n"
			"    RPN       Registered parameter being modified (see table below)\n"
			"    NRPN      Non-registered parameter being modified (0-16383)\n"
			"\n"
			"  Notes:\n"
			"    Notes are represented in the format of:\n"
			"      `Note<Key><Octave>`\n"
			"    Where Key can be one of the 12 keys, using flats:\n"
			"      Key = C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B\n"
			"    And Octave can be one of the 11 octaves, starting at -2 (represented as N2):\n"
			"      Octave = N2, N1, 0, 1, 2, 3, 4, 5, 6, 7, 8\n"
			"\n"
			"    The last addressable MIDI note is NoteG8, so NoteAb8, NoteA8, NoteBb8 and\n"
			"    NoteB8 do not exist.\n"
			"\n"
			"    Therefore, the entire range is: NoteCN2, NoteDbN2, ... NoteF8, NoteG8.\n"
			"\n"
			"  Low-Resolution Controls (MIDI hex value in parenthesis for reference):\n"
			"    ControlPedal      (40)          ControlGeneral5    (50)\n"
			"    ControlPortamento (41)          ControlGeneral6    (51)\n"
			"    ControlSostenuto  (42)          ControlGeneral7    (52)\n"
			"    ControlSoftPedal  (43)          ControlGeneral8    (53)\n"
			"    ControlLegato     (44)          ControlPortamento2 (54)\n"
			"    ControlHold2      (45)          ControlUndefined1  (55)\n"
			"    ControlSound1     (46)          ControlUndefined2  (56)\n"
			"    ControlSound2     (47)          ControlUndefined3  (57)\n"
			"    ControlSound3     (48)          ControlVelocityLow (58)\n"
			"    ControlSound4     (49)          ControlUndefined4  (59)\n"
			"    ControlSound5     (4A)          ControlUndefined5  (5A)\n"
			"    ControlSound6     (4B)          ControlEffect1     (5B)\n"
			"    ControlSound7     (4C)          ControlEffect2     (5C)\n"
			"    ControlSound8     (4D)          ControlEffect3     (5D)\n"
			"    ControlSound9     (4E)          ControlEffect4     (5E)\n"
			"    ControlSound10    (4F)          ControlEffect5     (5F)\n"
			"\n"
			"  High-Resolution Controls (MIDI hex values in parenthesis for reference):\n"
			"    ControlBank           (00/20)   ControlGeneral1    (10/30)\n"
			"    ControlMod            (01/21)   ControlGeneral2    (11/31)\n"
			"    ControlBreath         (02/22)   ControlGeneral3    (12/32)\n"
			"    ControlUndefined6     (03/23)   ControlGeneral4    (13/33)\n"
			"    ControlFoot           (04/24)   ControlUndefined10 (14/34)\n"
			"    ControlPortamentoTime (05/25)   ControlUndefined11 (15/35)\n"
			"    ControlChannelVolume  (07/27)   ControlUndefined12 (16/36)\n"
			"    ControlBalance        (08/28)   ControlUndefined13 (17/37)\n"
			"    ControlUndefined7     (09/29)   ControlUndefined14 (18/38)\n"
			"    ControlPan            (0A/2A)   ControlUndefined15 (19/39)\n"
			"    ControlExpression     (0B/2B)   ControlUndefined16 (1A/3A)\n"
			"    ControlEffect6        (0C/2C)   ControlUndefined17 (1B/3B)\n"
			"    ControlEffect7        (0D/2D)   ControlUndefined18 (1C/3C)\n"
			"    ControlUndefined8     (0E/2E)   ControlUndefined19 (1D/3D)\n"
			"    ControlUndefined9     (0F/2F)   ControlUndefined20 (1E/3E)\n"
			"                                    ControlUndefined21 (1F/3F)\n"
			"\n"
			"  Registered Parameters (MIDI hex values in parenthesis for reference):\n"
			"    RPNBendRange     (00/00)        RPNAzimuth          (3D/00)\n"
			"    RPNFineTuning    (00/01)        RPNElevation        (3D/01)\n"
			"    RPNCoarseTuning  (00/02)        RPNGain             (3D/02)\n"
			"    RPNTuningProgram (00/03)        RPNDistanceRatio    (3D/03)\n"
			"    RPNTuningBank    (00/04)        RPNMaxDistance      (3D/04)\n"
			"    RPNModRange      (00/05)        RPNGainAtMax        (3D/05)\n"
			"    RPNEmpty         (7F/7F)        RPNRefDistanceRatio (3D/06)\n"
			"                                    RPNPanSpread        (3D/07)\n"
			"                                    RPNRoll             (3D/08)\n"
			"\n"
			"  Commands:\n"
			"    Print \"Message\", \"Another\", ...              Print values to console\n"
			"      (`Print RawData` will print the raw bytes received in hexadecimal)\n"
			"    SendCopy                                         Send a copy of the message\n"
			"    SendNote         <Channel> <Note> <Velocity>\n"
			"      (Use 0 for Velocity to send note off)\n"
			"    SendBend         <Channel> <Bend>\n"
			"    SendNotePressure <Channel> <Note> <Pressure>\n"
			"    SendChanPressure <Channel> <Pressure>\n"
			"    SendPatch        <Channel> <Patch>\n"
			"    SendLowCC        <Channel> <Control> <Value>\n"
			"    SendHighCC       <Channel> <Control> <Value>\n"
			"    SendRPN          <Channel> <RPN> <Value>\n"
			"    SendNRPN         <Channel> <NRPN> <Value>\n"
			"    SendAllSoundOff  <Channel>\n"
			"    SendAllNotesOff  <Channel>\n"
			"    SendReset        <Channel>\n"
			"\n"
			"  For more information on specifying input devices, run:\n"
			"    midimap --help input\n"
		);
		return 0;
	}

	// look for help
	if (has_help){
		printf(
			"Usage:\n"
			"  midimap [-m \"Input Device\" <mapfile>]+\n"
			"\n"
			"  With no arguments specified, midimap will simply list the available sources\n"
			"  for MIDI input.\n"
			"\n"
			"  For every `-m` argument, the program will listen for MIDI messages from the\n"
			"  input device, and apply the rules outlined in the <mapfile> for every message\n"
			"  received.\n"
			"\n"
			"  The program will output the results to a single virtual MIDI device, named\n"
			"  in the format of \"midimap\", \"midimap 2\", \"midimap 3\", etc, for each\n"
			"  copy of the program running.\n"
			"\n"
			"  For more information on specifying input devices, run:\n"
			"    midimap --help input\n"
			"\n"
			"  For more information on how the mapfile works, run:\n"
			"    midimap --help mapfile\n"
		);
		return 0;
	}

	// initialize MIDI
	MIDIClientRef client;
	{
		OSStatus st = MIDIClientCreate((CFStringRef)@"midimap", midinotify, NULL, &client);
		if (st != 0){
			fprintf(stderr, "Failed to initialize MIDI\n");
			result = 1;
			goto cleanup;
		}
		init_midi = true;
	}

	// list sources
	{
		int len = MIDIGetNumberOfSources();
		if (len > MAX_SOURCES){
			fprintf(stderr,
				"Warning: System is reporting %d sources, but midimap only supports %d\n",
				len, MAX_SOURCES);
			len = MAX_SOURCES;
		}

		for (int i = 0; i < len; i++){
			MIDIEndpointRef src = MIDIGetSource(i);
			if (src == 0){
				fprintf(stderr, "Failed to get MIDI source %d\n", i + 1);
				continue;
			}
			int si = srcs_size++;
			srcs[si].ep = src;
			srcs[si].i = i + 1;
			srcs[si].name = NULL;
			srcs[si].size = 0;
			srcs[si].mfs = NULL;
			srcs[si].opened = false;
			CFStringRef name = nil;
			if (MIDIObjectGetStringProperty(src, kMIDIPropertyDisplayName, &name) == 0 &&
				name != nil){
				srcs[si].name = [(NSString *)name UTF8String];
			}
			if (srcs[si].name)
				printf("Source %d: \"%s\"\n", srcs[si].i, srcs[si].name);
			else
				printf("Source %d: No Name Available\n", srcs[si].i);
		}
		if (len == 0)
			printf("No MIDI Sources found!\n");
		printf("\n");
	}

	// interpret the command line arguments
	bool should_listen = false;
	{
		for (int i = 1; i < argc; i += 3){
			if (strcmp(argv[i], "-m") != 0 || i >= argc - 2){
				fprintf(stderr, "Invalid command line argument\nFor help, type:\n  midimap --help");
				result = 1;
				goto cleanup;
			}
			// look for the device
			int devi = -1;
			int srci = -1;
			parseint(argv[i + 1], &devi);
			for (int j = 0; j < srcs_size && srci == -1; j++){
				if (srcs[j].i == devi || strcmp(argv[i + 1], srcs[j].name) == 0)
					srci = j;
			}
			if (srci == -1){
				fprintf(stderr, "Failed to find MIDI device: %s\n", argv[i + 1]);
				result = 1;
				goto cleanup;
			}
			// parse the map file
			mapfile mf = mapfile_parse(argv[i + 2]);
			if (mf == NULL){
				result = 1;
				goto cleanup;
			}
			// add it to the device
			should_listen = true;
			srcs[srci].size++;
			srcs[srci].mfs = m_realloc(srcs[srci].mfs, sizeof(mapfile) * srcs[srci].size);
			srcs[srci].mfs[srcs[srci].size - 1] = mf;
		}
	}

	// check if anything needs to be done
	if (!should_listen){
		printf("Nothing to do\n");
		goto cleanup;
	}

	// create our virtual MIDI source
	{
		// create a unique name
		char *name = NULL;
		int namei = 1;
		while (true){
			if (namei == 1)
				name = format("midimap");
			else
				name = format("midimap %d", namei);
			// search if name is already used
			bool found = false;
			for (int i = 0; i < srcs_size && !found; i++)
				found = srcs[i].name && strcmp(name, srcs[i].name) == 0;
			if (found){
				free(name);
				namei++;
				continue;
			}
			break;
		}
		// create the device
		CFStringRef cfname = CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8);
		OSStatus st = MIDISourceCreate(client, cfname, &midiout);
		CFRelease(cfname);
		if (st != 0){
			fprintf(stderr, "Failed to create virtual MIDI endpoint \"%s\"\n", name);
			free(name);
			result = 1;
			goto cleanup;
		}
		init_out = true;
		printf("Virtual MIDI device for output:\n  %s\n\n", name);
		free(name);
	}

	// open MIDI devices
	{
		for (int i = 0; i < srcs_size; i++){
			if (srcs[i].size <= 0)
				continue;
			// intialize midi context
			srcs[i].mctx.size = srcs[i].size;
			srcs[i].mctx.mfs = srcs[i].mfs;
			for (int c = 0; c < 32; c++)
				srcs[i].mctx.cc[c] = 0;
			MIDIPortRef pref = 0;
			OSStatus pst = MIDIInputPortCreate(client, (CFStringRef)@"midimap-ip",
				(MIDIReadProc)midiread, &srcs[i].mctx, &pref);
			if (pst != 0){
				fprintf(stderr, "Failed to open Source %d for reading\n", srcs[i].i);
				result = 1;
				goto cleanup;
			}
			OSStatus nst = MIDIPortConnectSource(pref, srcs[i].ep, NULL);
			if (nst != 0){
				MIDIPortDispose(pref);
				fprintf(stderr, "Failed to open Source %d for reading\n", srcs[i].i);
				result = 1;
				goto cleanup;
			}
			srcs[i].opened = true;
			srcs[i].pref = pref;
			if (srcs[i].name)
				printf("Listening to Source %d: \"%s\"\n", srcs[i].i, srcs[i].name);
			else
				printf("Listening to Source %d: No Name Available\n", srcs[i].i);
		}
	}

	// wait for signal from Ctrl+C
	{
		printf("Press Ctrl+C to Quit\n");
		signal(SIGINT, catchdone);
		signal(SIGSTOP, catchdone);
		pthread_mutex_init(&done_mutex, NULL);
		pthread_cond_init(&done_cond, NULL);
		pthread_mutex_lock(&done_mutex);
		done = false;
		while (!done)
			pthread_cond_wait(&done_cond, &done_mutex);
		pthread_mutex_unlock(&done_mutex);
		pthread_mutex_destroy(&done_mutex);
		pthread_cond_destroy(&done_cond);
		printf("\nQuitting...\n");
	}

	cleanup:
	for (int i = 0; i < srcs_size; i++){
		if (srcs[i].opened){
			MIDIPortDisconnectSource(srcs[i].pref, srcs[i].ep);
			MIDIPortDispose(srcs[i].pref);
		}
		for (int j = 0; j < srcs[i].size; j++)
			mapfile_free(srcs[i].mfs[j]);
		m_free(srcs[i].mfs);
	}
	if (init_out)
		MIDIEndpointDispose(midiout);
	if (init_midi)
		MIDIClientDispose(client);
	return result;
}
