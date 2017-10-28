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

static char *format(const char *fmt, ...){
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
			"    Note      Note value (NoteC0-NoteG8) Use flats for black keys: NoteDb4, etc\n"
			"    Velocity  How hard the note was hit (0-127) Use 0 for note off\n"
			"    Bend      Amount to bend (0-16383, center at 8192)\n"
			"    Pressure  Aftertouch intensity (0-127)\n"
			"    Patch     Patch being selected (0-127)\n"
			"    Control   Control being modified (see table below)\n"
			"    Value     Value for the control (LowCC: 0-127, HighCC/RPN/NRPN: 0-16383)\n"
			"    RPN       Registered parameter being modified (see table below)\n"
			"    NRPN      Non-registered parameter being modified (0-16383)\n"
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
