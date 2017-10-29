midimap
=======

Command line tool for generating and mapping MIDI messages for Mac OSX.

Example Use Cases
=================

### Playing a chord when hitting a single button

```
OnNote Any NoteC3 Any
  # if a C3 is hit, then send a C3+E3+G3
  SendNote Channel NoteC3 Velocity
  SendNote Channel NoteE3 Velocity
  SendNote Channel NoteG3 Velocity
End

OnElse
  # if anything else is hit, pass it along
  SendCopy
End
```

### Map a note to the sustain pedal

```
OnNote Any NoteC3 0
  # if C3 is released, release the pedal
  SendLowCC Channel ControlPedal 0
End

OnNote Any NoteC3 Positive
  # if C3 is hit, hit the pedal
  SendLowCC Channel ControlPedal 127
End

OnElse
  # anything else, pass it along
  SendCopy
End
```

### Stop a device from sending Reset commands

```
OnReset Any
  # do nothing
End

OnElse
  # anything else, pass it along
  SendCopy
End
```

### Print out note velocities

```
OnNote Any Any Positive
  # spy on all note hit events and print them
  Print "HIT:" Note Velocity
  SendCopy
End

OnElse
  # anything else, pass it along
  SendCopy
End
```

Usage
=====

```
Usage:
  midimap [-m "Input Device" <mapfile>]+

  With no arguments specified, midimap will simply list the available sources
  for MIDI input.

  For every `-m` argument, the program will listen for MIDI messages from the
  input device, and apply the rules outlined in the <mapfile> for every message
  received.

  The program will output the results to a single virtual MIDI device, named
  in the format of "midimap", "midimap 2", "midimap 3", etc, for each
  copy of the program running.

Input Devices:
  The program will always list out the available input devices.  For example:
    Source 1: "Keyboard A"
    Source 2: "Keyboard B"
    Source 3: No Name Available
    Source 4: "Pads"
    Source 5: "Pads"

  Sources can be specified using the name:
    # selects the source named "Keyboard A"
    midimap -m "Keyboard A" <mapfile>
  Or the source index:
    # selects source index 5
    midimap -m 5 <mapfile>

Map Files:
  Map files consist of a list of event handlers.  If the handler's criteria
  matches the message, the instructions in the handler are executed, and no
  further handlers are executed.

    OnNote 1 NoteGb3 Any
      # Change the Gb3 to a C4
      Print "Received:" Channel Note Velocity
      SendNote 16 NoteC4 Velocity
    End

  For this example, if the input device sends a Gb3 message at any velocity in
  channel 1, the program will print the message, and send a C4 instead on
  channel 16.

  The first line is what message to intercept, and the matching criteria
  for the message.  Criteria can be a literal value, `Any` which matches
  anything, or `Positive` for a number greater than zero.  Inside the handler,
  the instructions are executed in order using raw values ("Received:", 16,
  NoteC4) or values dependant on the original message (Channel, Note,
  Velocity).

  Any line that begins with a `#` is ignored and considered a comment.

  All event handlers end with `End`.

  Event Handlers:
    OnNote         <Channel> <Note> <Velocity>  Note is hit or released
    OnBend         <Channel> <Bend>             Pitch bend for entire channel
    OnNotePressure <Channel> <Note> <Pressure>  Aftertouch applied to note
    OnChanPressure <Channel> <Pressure>         Aftertouch for entire channel
    OnPatch        <Channel> <Patch>            Program change patch
    OnLowCC        <Channel> <Control> <Value>  Low-res control change
    OnHighCC       <Channel> <Control> <Value>  High-res control change
    OnRPN          <Channel> <RPN> <Value>      Registered device parameter
    OnNRPN         <Channel> <NRPN> <Value>     Custom device parameter
    OnAllSoundOff  <Channel>                    All Sound Off message
    OnAllNotesOff  <Channel>                    All Notes Off message
    OnReset        <Channel>                    Reset All Controllers message
    OnElse                                      Messages not matched

  Parameters:
    Channel   MIDI Channel (1-16)
    Note      Note value (see details below)
    Velocity  How hard the note was hit (0-127) Use 0 for note off
    Bend      Amount to bend (0-16383, center at 8192)
    Pressure  Aftertouch intensity (0-127)
    Patch     Patch being selected (0-127)
    Control   Control being modified (see table below)
    Value     Value for the control (LowCC: 0-127, HighCC/RPN/NRPN: 0-16383)
    RPN       Registered parameter being modified (see table below)
    NRPN      Non-registered parameter being modified (0-16383)

  Notes:
    Notes are represented in the format of:
      `Note<Key><Octave>`
    Where Key can be one of the 12 keys, using flats:
      Key = C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B
    And Octave can be one of the 11 octaves, starting at -2 (represented as N2):
      Octave = N2, N1, 0, 1, 2, 3, 4, 5, 6, 7, 8

    The last addressable MIDI note is NoteG8, so NoteAb8, NoteA8, NoteBb8 and
    NoteB8 do not exist.

    Therefore, the entire range is: NoteCN2, NoteDbN2, ... NoteF8, NoteG8.

  Low-Resolution Controls (MIDI hex value in parenthesis for reference):
    ControlPedal      (40)          ControlGeneral5    (50)
    ControlPortamento (41)          ControlGeneral6    (51)
    ControlSostenuto  (42)          ControlGeneral7    (52)
    ControlSoftPedal  (43)          ControlGeneral8    (53)
    ControlLegato     (44)          ControlPortamento2 (54)
    ControlHold2      (45)          ControlUndefined1  (55)
    ControlSound1     (46)          ControlUndefined2  (56)
    ControlSound2     (47)          ControlUndefined3  (57)
    ControlSound3     (48)          ControlVelocityLow (58)
    ControlSound4     (49)          ControlUndefined4  (59)
    ControlSound5     (4A)          ControlUndefined5  (5A)
    ControlSound6     (4B)          ControlEffect1     (5B)
    ControlSound7     (4C)          ControlEffect2     (5C)
    ControlSound8     (4D)          ControlEffect3     (5D)
    ControlSound9     (4E)          ControlEffect4     (5E)
    ControlSound10    (4F)          ControlEffect5     (5F)

  High-Resolution Controls (MIDI hex values in parenthesis for reference):
    ControlBank           (00/20)   ControlGeneral1    (10/30)
    ControlMod            (01/21)   ControlGeneral2    (11/31)
    ControlBreath         (02/22)   ControlGeneral3    (12/32)
    ControlUndefined6     (03/23)   ControlGeneral4    (13/33)
    ControlFoot           (04/24)   ControlUndefined10 (14/34)
    ControlPortamentoTime (05/25)   ControlUndefined11 (15/35)
    ControlChannelVolume  (07/27)   ControlUndefined12 (16/36)
    ControlBalance        (08/28)   ControlUndefined13 (17/37)
    ControlUndefined7     (09/29)   ControlUndefined14 (18/38)
    ControlPan            (0A/2A)   ControlUndefined15 (19/39)
    ControlExpression     (0B/2B)   ControlUndefined16 (1A/3A)
    ControlEffect6        (0C/2C)   ControlUndefined17 (1B/3B)
    ControlEffect7        (0D/2D)   ControlUndefined18 (1C/3C)
    ControlUndefined8     (0E/2E)   ControlUndefined19 (1D/3D)
    ControlUndefined9     (0F/2F)   ControlUndefined20 (1E/3E)
                                    ControlUndefined21 (1F/3F)

  Registered Parameters (MIDI hex values in parenthesis for reference):
    RPNBendRange     (00/00)        RPNAzimuth          (3D/00)
    RPNFineTuning    (00/01)        RPNElevation        (3D/01)
    RPNCoarseTuning  (00/02)        RPNGain             (3D/02)
    RPNTuningProgram (00/03)        RPNDistanceRatio    (3D/03)
    RPNTuningBank    (00/04)        RPNMaxDistance      (3D/04)
    RPNModRange      (00/05)        RPNGainAtMax        (3D/05)
    RPNEmpty         (7F/7F)        RPNRefDistanceRatio (3D/06)
                                    RPNPanSpread        (3D/07)
                                    RPNRoll             (3D/08)

  Commands:
    Print "Message", "Another", ...              Print values to console
      (`Print RawData` will print the raw bytes received in hexadecimal)
    SendCopy                                     Send a copy of the message
    SendNote         <Channel> <Note> <Velocity>
      (Use 0 for Velocity to send note off)
    SendBend         <Channel> <Bend>
    SendNotePressure <Channel> <Note> <Pressure>
    SendChanPressure <Channel> <Pressure>
    SendPatch        <Channel> <Patch>
    SendLowCC        <Channel> <Control> <Value>
    SendHighCC       <Channel> <Control> <Value>
    SendRPN          <Channel> <RPN> <Value>
    SendNRPN         <Channel> <NRPN> <Value>
    SendAllSoundOff  <Channel>
    SendAllNotesOff  <Channel>
    SendReset        <Channel>
```
