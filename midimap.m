// (c) Copyright 2017, Sean Connelly (@voidqk), http://syntheti.cc
// MIT License
// Project Home: https://github.com/voidqk/midimap

#include <stdio.h>
#include <stdlib.h>
#import <Foundation/Foundation.h>
#include <CoreMIDI/CoreMIDI.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <signal.h>

/*
void midiread(const MIDIPacketList *pkl, osxmidi_src_st *src, void *dummy){
	const MIDIPacket *p = &pkl->packet[0];
	for (int i = 0; i < pkl->numPackets; i++){
		// p->timeStamp, p->length, p->data
		p = MIDIPacketNext(p);
	}
}

bool osxmidi_src_open(int src_id, osxmidi_src_st *src){
	MIDIEndpointRef msrc = MIDIGetSource(src_id);
	if (msrc == 0)
		return false;

	MIDIPortRef pref = 0;
	OSStatus pst = MIDIInputPortCreate(client_ref, (CFStringRef)@"paralysis-ip",
		(MIDIReadProc)midiread, src, &pref);
	if (pst != 0)
		return false;

	OSStatus nst = MIDIPortConnectSource(pref, msrc, NULL);
	if (nst != 0){
		MIDIPortDispose(pref);
		return false;
	}
}

void osxmidi_src_close(osxmidi_src_st *src){
	MIDIPortDisconnectSource((MIDIPortRef)src->port, (MIDIEndpointRef)src->endpoint);
	MIDIPortDispose((MIDIPortRef)src->port);
}
*/

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
	X(_Any           ,   -1,   -1) \
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
	X(_Any            ,   -1,   -1) \
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
		#define X(name, v)   case v: return "Note" # name;
		EACH_NOTE(X)
		#undef X
	}
	return "<Unknown>";
}

bool note_fromname(const char *str, int *note){
	#define X(name, v)                         \
		if (strcmp(str, "Note" # name) == 0){  \
			*note = v;                         \
			return true;                       \
		}
	EACH_NOTE(X)
	#undef X
	return false;
}

typedef enum {
	MA_VAL_NUM,
	MA_VAL_STR,
	MA_VAL_NOTE,
	MA_VAL_LOWCC,
	MA_VAL_HIGHCC,
	MA_VAL_RPN,
	MA_RAWDATA,
	MA_CHANNEL,
	MA_NOTE,
	MA_VELOCITY,
	MA_BEND,
	MA_PRESSURE,
	MA_PATCH,
	MA_CONTROL,
	MA_VALUE,
	MA_RPN,
	MA_NRPN
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
			lowcc_type control;
			int value;
		} lowcc;
		struct {
			highcc_type control;
			int value;
		} highcc;
		struct {
			rpn_type rpn;
			int value;
		} rpn;
		struct {
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

char *format(const char *fmt, ...){
	va_list args, args2;
	va_start(args, fmt);
	va_copy(args2, args);
	size_t s = vsnprintf(NULL, 0, fmt, args);
	char *buf = malloc(s + 1);
	if (buf == NULL){
		fprintf(stderr, "Fatal Error: Out of memory!\n");
		exit(1);
		return NULL;
	}
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

double ts_numer, ts_denom;
inline double ts_sec(double ts){
	return ts * ts_numer / ts_denom;
}

inline double ts_unsec(double ts){
	return ts * ts_denom / ts_numer;
}

inline double ts_now(){
	return ts_sec(mach_absolute_time());
}

bool done = false;
pthread_mutex_t done_mutex;
pthread_cond_t done_cond;
void catchdone(int dummy){
	pthread_mutex_lock(&done_mutex);
	done = true;
	pthread_mutex_unlock(&done_mutex);
	pthread_cond_signal(&done_cond);
}

MIDIEndpointRef midiout;

int main(int argc, char **argv){
	int result = 0;
	bool init_midi = false;
	bool init_out = false;

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
			"    OnNote 1, NoteGb3, Any\n"
			"      # Change the Gb3 to a C4\n"
			"      Print \"Received:\", Channel, Note, Velocity\n"
			"      SendNote 16, NoteC4, Velocity\n"
			"    End\n"
			"\n"
			"  For this example, if the input device sends a Gb3 message at any velocity in\n"
			"  channel 1, the program will print the message, and send a C4 instead on\n"
			"  channel 16.\n"
			"\n"
			"  The first line is what message to intercept, and the matching criteria\n"
			"  for the message.  Criteria can be a literal value, or `Any` which matches\n"
			"  anything.  Inside the handler, the instructions are executed in order using\n"
			"  raw values (\"Received:\", 16, NoteC4) or values dependant on the original\n"
			"  message (Channel, Note, Velocity).\n"
			"\n"
			"  Any line that begins with a `#` is ignored and considered a comment.\n"
			"\n"
			"  All event handlers end with `End`.\n"
			"\n"
			"  Event Handlers:\n"
			"    OnNote         <Channel>, <Note>, <Velocity>  Note is hit or released\n"
			"    OnBend         <Channel>, <Bend>              Pitch bend for entire channel\n"
			"    OnNotePressure <Channel>, <Note>, <Pressure>  Aftertouch applied to note\n"
			"    OnChanPressure <Channel>, <Pressure>          Aftertouch for entire channel\n"
			"    OnPatch        <Channel>, <Patch>             Program change patch\n"
			"    OnLowCC        <Channel>, <Control>, <Value>  Low-res control change\n"
			"    OnHighCC       <Channel>, <Control>, <Value>  High-res control change\n"
			"    OnRPN          <Channel>, <RPN>, <Value>      Registered device parameter\n"
			"    OnNRPN         <Channel>, <NRPN>, <Value>     Custom device parameter\n"
			"    OnAllSoundOff  <Channel>                      All Sound Off message\n"
			"    OnAllNotesOff  <Channel>                      All Notes Off message\n"
			"    OnReset        <Channel>                      Reset All Controllers message\n"
			"    OnElse                                        Messages not matched\n"
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
			"    SendNote         <Channel>, <Note>, <Velocity>\n"
			"      (Use 0 for Velocity to send note off)\n"
			"    SendBend         <Channel>, <Bend>\n"
			"    SendNotePressure <Channel>, <Note>, <Pressure>\n"
			"    SendChanPressure <Channel>, <Pressure>\n"
			"    SendPatch        <Channel>, <Patch>\n"
			"    SendLowCC        <Channel>, <Control>, <Value>\n"
			"    SendHighCC       <Channel>, <Control>, <Value>\n"
			"    SendRPN          <Channel>, <RPN>, <Value>\n"
			"    SendNRPN         <Channel>, <NRPN>, <Value>\n"
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

	// get timing information for converting timestamps to seconds
	{
		mach_timebase_info_data_t ts;
		mach_timebase_info(&ts);
		ts_numer = ts.numer;
		ts_denom = ts.denom * 1000000000.0;
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
	#define MAX_SOURCES 100
	int srcs_size = 0;
	MIDIEndpointRef srcs[MAX_SOURCES];
	const char *srcnames[MAX_SOURCES];
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
			srcs[si] = src;
			srcnames[si] = NULL;
			CFStringRef name = nil;
			if (MIDIObjectGetStringProperty(src, kMIDIPropertyDisplayName, &name) == 0 &&
				name != nil){
				srcnames[si] = [(NSString *)name UTF8String];
			}
			if (srcnames[si])
				printf("Source %d: \"%s\"\n", i + 1, srcnames[si]);
			else
				printf("Source %d: No Name Available\n", i + 1);
		}
	}

	// interpret the command line arguments

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
				found = srcnames[i] && strcmp(name, srcnames[i]) == 0;
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
		printf("Virtual MIDI device: %s\n", name);
		free(name);
	}

	// wait for signal from Ctrl+C
	{
		printf("Press Ctrl+C to Quit\n");
		signal(SIGINT, catchdone);
		signal(SIGSTOP, catchdone);
		pthread_mutex_init(&done_mutex, NULL);
		pthread_cond_init(&done_cond, NULL);
		pthread_mutex_lock(&done_mutex);
		while (!done)
			pthread_cond_wait(&done_cond, &done_mutex);
		pthread_mutex_unlock(&done_mutex);
		pthread_mutex_destroy(&done_mutex);
		pthread_cond_destroy(&done_cond);
		printf("\nQuitting...\n");
	}

	cleanup:
	if (init_out)
		MIDIEndpointDispose(midiout);
	if (init_midi)
		MIDIClientDispose(client);
	return result;
}
