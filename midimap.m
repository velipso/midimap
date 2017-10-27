// (c) Copyright 2017, Sean Connelly (@voidqk), http://syntheti.cc
// MIT License
// Project Home: https://github.com/voidqk/midimap

#include <stdio.h>
#import <Foundation/Foundation.h>
#include <CoreMIDI/CoreMIDI.h>
#include <mach/mach_time.h>
#include <pthread.h>

#define OSXMIDI_SOURCE_BUFFER_SIZE  2000

typedef struct osxmidi_msg_struct {
	uint8_t bytes[256];
	double timestamp;
	int size;
} osxmidi_msg_st;

typedef struct osxmidi_src_struct {
	const char *name;
	osxmidi_msg_st buffer[OSXMIDI_SOURCE_BUFFER_SIZE];
	int read;
	int write;
	uintptr_t endpoint;
	uintptr_t port;
	uintptr_t mutex;
	uintptr_t cond;
} osxmidi_src_st;

typedef struct osxmidi_tgt_struct {
	const char *name;
	uintptr_t endpoint;
	uintptr_t port;
} osxmidi_tgt_st;

MIDIClientRef client_ref;

double ts_numer, ts_denom;
inline double ts_sec(double ts){
	return ts * ts_numer / ts_denom;
}

inline double ts_unsec(double ts){
	return ts * ts_denom / ts_numer;
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
	fprintf(stderr, "[osxmidi] midinotify: %s\n", msg);
}

bool osxmidi_init(){
	mach_timebase_info_data_t ts;
	mach_timebase_info(&ts);
	ts_numer = ts.numer;
	ts_denom = ts.denom * 1000000000.0;
	OSStatus cst = MIDIClientCreate((CFStringRef)@"paralysis-mc", midinotify, NULL, &client_ref);
	if (cst != 0)
		return false;
	return true;
}

double osxmidi_now(){
	return ts_sec(mach_absolute_time());
}

int osxmidi_src_count(){
	return MIDIGetNumberOfSources();
}

const char *getname(MIDIObjectRef obj){
	CFStringRef name = nil;
	if (MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &name) != 0)
		return NULL;
	if (name == nil)
		return NULL;
	return [(NSString *)name UTF8String];
}

const char *osxmidi_src_name(int src_id){
	return getname(MIDIGetSource(src_id));
}

void midiread(const MIDIPacketList *pkl, osxmidi_src_st *src, void *dummy){
	const MIDIPacket *p = &pkl->packet[0];
	pthread_mutex_lock((pthread_mutex_t *)src->mutex);
	for (int i = 0; i < pkl->numPackets; i++){
		int idx = src->write;
		int write_next = (idx + 1) % OSXMIDI_SOURCE_BUFFER_SIZE;
		if (write_next == src->read){
			// buffer is full! drop the remaining packets :-(
			fprintf(stderr, "[osxmidi] midi packets dropped due to full buffer\n");
			break;
		}
		src->buffer[idx].timestamp = ts_sec(p->timeStamp);
		src->buffer[idx].size = p->length;
		memcpy(src->buffer[idx].bytes, p->data, sizeof(uint8_t) * p->length);
		src->write = write_next;
		p = MIDIPacketNext(p);
	}
	pthread_cond_signal((pthread_cond_t *)src->cond);
	pthread_mutex_unlock((pthread_mutex_t *)src->mutex);
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

	pthread_mutex_t *mutex = malloc(sizeof(pthread_mutex_t));
	if (mutex == NULL){
		MIDIPortDisconnectSource(pref, msrc);
		MIDIPortDispose(pref);
		return false;
	}
	pthread_mutex_init(mutex, NULL);

	pthread_cond_t *cond = malloc(sizeof(pthread_cond_t));
	if (cond == NULL){
		pthread_mutex_destroy(mutex);
		free(mutex);
		MIDIPortDisconnectSource(pref, msrc);
		MIDIPortDispose(pref);
		return false;
	}
	pthread_cond_init(cond, NULL);

	src->read = src->write = 0;
	src->name     = getname(msrc);
	src->endpoint = (uintptr_t)msrc;
	src->port     = (uintptr_t)pref;
	src->mutex    = (uintptr_t)mutex;
	src->cond     = (uintptr_t)cond;
	return true;
}

void osxmidi_src_close(osxmidi_src_st *src){
	MIDIPortDisconnectSource((MIDIPortRef)src->port, (MIDIEndpointRef)src->endpoint);
	MIDIPortDispose((MIDIPortRef)src->port);
	pthread_mutex_destroy((pthread_mutex_t *)src->mutex);
	free((void *)src->mutex);
	pthread_cond_destroy((pthread_cond_t *)src->cond);
	free((void *)src->cond);
}

inline void readmsg(osxmidi_src_st *src, osxmidi_msg_st *msg){
	msg->timestamp = src->buffer[src->read].timestamp;
	msg->size = src->buffer[src->read].size;
	memcpy(msg->bytes, src->buffer[src->read].bytes, sizeof(uint8_t) * msg->size);
	src->read = (src->read + 1) % OSXMIDI_SOURCE_BUFFER_SIZE;
}

bool osxmidi_src_tryread(osxmidi_src_st *src, osxmidi_msg_st *msg){
	bool res = false;
	pthread_mutex_lock((pthread_mutex_t *)src->mutex);
	if (src->read != src->write){
		res = true;
		readmsg(src, msg);
	}
	pthread_mutex_unlock((pthread_mutex_t *)src->mutex);
	return res;
}

void osxmidi_src_waitread(osxmidi_src_st *src, osxmidi_msg_st *msg){
	pthread_mutex_lock((pthread_mutex_t *)src->mutex);
	while (src->read == src->write)
		pthread_cond_wait((pthread_cond_t *)src->cond, (pthread_mutex_t *)src->mutex);
	readmsg(src, msg);
	pthread_mutex_unlock((pthread_mutex_t *)src->mutex);
}

int osxmidi_tgt_count(){
	return MIDIGetNumberOfDestinations();
}

const char *osxmidi_tgt_name(int tgt_id){
	return getname(MIDIGetDestination(tgt_id));
}

bool osxmidi_tgt_open(int tgt_id, osxmidi_tgt_st *tgt){
	MIDIEndpointRef mtgt = MIDIGetDestination(tgt_id);
	if (mtgt == 0)
		return false;

	MIDIPortRef pref = 0;
	OSStatus pst = MIDIOutputPortCreate(client_ref, (CFStringRef)@"paralysis-op", &pref);
	if (pst != 0)
		return false;

	//OSStatus nst = MIDIPortConnectSource(pref, mtgt, NULL);
	//if (nst != 0){
	//	MIDIPortDispose(pref);
	//	return false;
	//}

	tgt->name     = getname(mtgt);
	tgt->endpoint = (uintptr_t)mtgt;
	tgt->port     = (uintptr_t)pref;
	return true;
}

void osxmidi_tgt_close(osxmidi_tgt_st *tgt){
	MIDIPortDisconnectSource((MIDIPortRef)tgt->port, (MIDIEndpointRef)tgt->endpoint);
	MIDIPortDispose((MIDIPortRef)tgt->port);
}

bool osxmidi_tgt_send(osxmidi_tgt_st *tgt, int msgcount, osxmidi_msg_st *msgs){
	uint8_t buffer[1000];
	MIDIPacketList *pkl = (MIDIPacketList *)buffer;
	int next = 0;
	while (next < msgcount){
		MIDIPacket *pk = MIDIPacketListInit(pkl);
		for (; next < msgcount; next++){
			pk = MIDIPacketListAdd(pkl, sizeof(buffer), pk,
				(MIDITimeStamp)ts_unsec(msgs[next].timestamp), msgs[next].size, msgs[next].bytes);
			if (pk == NULL)
				break;
		}
		OSStatus sst = MIDISend((MIDIPortRef)tgt->port, (MIDIEndpointRef)tgt->endpoint, pkl);
		if (sst != 0)
			return false;
	}
	return true;
}

void osxmidi_term(){
	MIDIClientDispose(client_ref);
}

int main(int argc, char **argv){
	printf("hello, world\n");
	return 0;
}
