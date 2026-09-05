// SPDX-License-Identifier: MIT
typedef unsigned int u32;
typedef signed int i32;
typedef signed char i8;
#include "vectors.h"
#define MMIO(addr) (*(volatile u32 *)(addr))
#define CONTROL MMIO(0x40000000u)
#define STATUS MMIO(0x40000004u)
#define RESULT MMIO(0x40000008u)
#define COMPUTE MMIO(0x4000000cu)
#define COUNTER MMIO(0x40000100u)
#define UART_DATA MMIO(0x40000104u)
#define UART_BUSY MMIO(0x40000108u)
#define LED_STATUS MMIO(0x4000010cu)
static volatile i8 a[8], b[8];
static volatile u32 initialized_cookie = 0x12345678u;
static volatile u32 zero_cookie;

static inline void barrier(void) { __asm__ volatile ("" ::: "memory"); }
static u32 now(void) { barrier(); u32 x=COUNTER; barrier(); return x; }

// Bounded eight-round unsigned shift/add; no signed-left-shift undefined behavior.
__attribute__((noinline)) static i32 multiply_i8(i32 x, i32 y) {
    u32 ax = x < 0 ? (u32)(-x) : (u32)x;
    u32 ay = y < 0 ? (u32)(-y) : (u32)y;
    u32 p = 0;
    for (u32 bit=0; bit<8; ++bit) {
        if (ay & 1u) p += ax;
        ax <<= 1; ay >>= 1;
    }
    return (x < 0) != (y < 0) ? -(i32)p : (i32)p;
}
__attribute__((noinline)) static i32 software_dot(void) {
    i32 sum=0;
    for (u32 i=0;i<8;++i) sum += multiply_i8(a[i], b[i]);
    return sum;
}
static void putc_uart(char c) {
    u32 timeout=1000000;
    while (UART_BUSY & 1u) {
        if (--timeout == 0) { LED_STATUS=2; for (;;) {} }
    }
    UART_DATA=(u32)(unsigned char)c;
}
static void text(const char *s) { while (*s) putc_uart(*s++); }
static void hex(u32 x) {
    for (i32 shift=28; shift>=0; shift-=4) {
        u32 digit=(x >> shift)&15u;
        putc_uart((char)(digit<10 ? '0'+digit : 'a'+digit-10));
    }
}
static void fail(const char *why, u32 id) {
    LED_STATUS=2; text("FAIL "); text(why); text(" ID="); hex(id); text("\n");
    for (;;) {}
}
int main(void) {
    if (initialized_cookie != 0x12345678u || zero_cookie != 0) fail("STARTUP",0);
    zero_cookie=1;
    u32 overhead0=now(); u32 overhead1=now();
    text("COUNTER_READ_DELTA="); hex(overhead1-overhead0); text("\n");
    for (u32 id=0; id<CASE_COUNT; ++id) {
        for (u32 i=0;i<8;++i) { a[i]=test_cases[id].a[i]; b[i]=test_cases[id].b[i]; }
        u32 sw_start=now();
        i32 sw=software_dot();
        u32 sw_end=now();
        if (sw != test_cases[id].expected) fail("SOFTWARE",id);
#ifndef CPU_ONLY
        // Measured region includes all 16 input transfers, start, bounded polling,
        // and the completed-result read. Input preparation and UART are outside.
        u32 hw_start=now();
        for (u32 i=0;i<8;++i) {
            MMIO(0x40000020u+4*i)=(u32)(i32)a[i];
            MMIO(0x40000040u+4*i)=(u32)(i32)b[i];
        }
        CONTROL=1;
        u32 timeout=10000;
        while ((STATUS & 2u)==0) if (--timeout==0) fail("TIMEOUT",id);
        i32 hw=(i32)RESULT;
        u32 hw_end=now();
        u32 compute=COMPUTE;
        if (hw != sw || hw != test_cases[id].expected || compute != 8) fail("HARDWARE",id);
        text("TEST="); hex(id); text(" SW="); hex((u32)sw);
        text(" HW="); hex((u32)hw); text(" CPU="); hex(sw_end-sw_start);
        text(" ACC="); hex(compute); text(" E2E="); hex(hw_end-hw_start); text(" PASS\n");
#else
        text("CPU_TEST="); hex(id); text(" SW="); hex((u32)sw);
        text(" CPU="); hex(sw_end-sw_start); text(" PASS\n");
#endif
    }
#ifdef CPU_ONLY
    text("ALL CPU PASS\n");
#else
    text("ALL PASS\n");
#endif
    // Drain the final stop bit before making the persistent PASS LED visible.
    u32 timeout=1000000;
    while (UART_BUSY & 1u) if (--timeout==0) fail("UART",0);
    LED_STATUS=1;
    for (;;) {}
}
