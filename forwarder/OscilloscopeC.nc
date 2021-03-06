#include "Timer.h"
#include "Oscilloscope.h"

module OscilloscopeC @safe()
{
  uses {
    interface Boot;
    interface SplitControl as RadioControl;
    interface AMSend;
    interface Receive;
    interface Leds;
  }
}
implementation
{
  message_t sendBuf;
  bool sendBusy;
  oscilloscope_t local;
  int i;

  uint8_t reading; /* 0 to NREADINGS */
  bool suppressCountChange;

  void report_problem() { call Leds.led0Toggle(); }
  void report_sent() { call Leds.led1Toggle(); }
  void report_received() { call Leds.led2Toggle(); }

  event void Boot.booted() {
    if (call RadioControl.start() != SUCCESS)
      report_problem();
  }

  event void RadioControl.startDone(error_t error) {
  }

  event void RadioControl.stopDone(error_t error) {
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    oscilloscope_t *omsg = payload;

    report_received();

    local.version  = omsg->version;
    local.interval = omsg->interval;
    local.count    = omsg->count;
    local.id       = omsg->id;

    for (i = 0; i < NREADINGS; ++i) {
        local.readings[i] = omsg->readings[i];
    }

    if (!sendBusy && sizeof local <= call AMSend.maxPayloadLength())
          {

            memcpy(call AMSend.getPayload(&sendBuf, sizeof(local)), &local, sizeof local);
            if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof local) == SUCCESS)
              sendBusy = TRUE;
          }
        if (!sendBusy)
          report_problem();

    return msg;
  }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if (error == SUCCESS)
      report_sent();
    else
      report_problem();

    sendBusy = FALSE;
  }


}
