// SPDX-License-Identifier: MIT
// GUI protocol v1. All measured work runs on the RTL RV32I CPU/accelerator.
typedef unsigned int u32;
typedef signed int i32;
typedef signed char i8;
typedef unsigned char u8;
#define MMIO(a) (*(volatile u32 *)(a))
#define CONTROL MMIO(0x40000000u)
#define STATUS MMIO(0x40000004u)
#define RESULT MMIO(0x40000008u)
#define COMPUTE MMIO(0x4000000cu)
#define COUNTER MMIO(0x40000100u)
#define UART_DATA MMIO(0x40000104u)
#define UART_BUSY MMIO(0x40000108u)
#define LED_STATUS MMIO(0x4000010cu)
#define RX_DATA MMIO(0x40000110u)
#define RX_STATUS MMIO(0x40000114u)
#define RX_TIMEOUT 2500000u
static volatile i8 a[8],b[8];
static inline void barrier(void) { __asm__ volatile ("" ::: "memory"); }
static u32 now(void) { barrier(); u32 v=COUNTER; barrier(); return v; }
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

static u8 crc_step(u8 crc,u8 value) {
    crc^=value;
    for(u32 i=0;i<8;++i) crc=(u8)((crc<<1)^((crc&128u)?7u:0u));
    return crc;
}
static u8 output_crc;
static void raw(char c) {
    // The transmitter is bounded by a frame. A stuck transmitter must not trap
    // the receive loop permanently, even though its error cannot be sent reliably.
    u32 start=now();
    while(UART_BUSY&1u) if((u32)(now()-start)>RX_TIMEOUT) { LED_STATUS=2; return; }
    UART_DATA=(u8)c;
}
static void putc_uart(char c) { output_crc=crc_step(output_crc,(u8)c); raw(c); }
static void text(const char *s) { while(*s) putc_uart(*s++); }
static void end_line(void) {
    const char digits[]="0123456789ABCDEF";
    raw('*');raw(digits[output_crc>>4]);raw(digits[output_crc&15]);raw('\r');raw('\n');output_crc=0;
}
static u32 divide_u32(u32 n, u32 d, u32 *remainder) {
    u32 q=0, r=0;
    for (i32 bit=31; bit>=0; --bit) {
        u32 carry=r>>31;
        r=(r<<1)|((n>>bit)&1u);
        if (carry || r>=d) { r-=d; q|=1u<<bit; }
    }
    *remainder=r;
    return q;
}
static void decimal(u32 x) {
    char digits[10]; u32 count=0;
    do {
        u32 remainder;
        x=divide_u32(x,10,&remainder);
        digits[count++]=(char)('0'+remainder);
    } while (x);
    while(count) putc_uart(digits[--count]);
}
static void signed_decimal(i32 x) {
    if(x<0) { putc_uart('-'); decimal(0u-(u32)x); }
    else decimal((u32)x);
}

static void error(u32 seq,const char *reason) {
    text("ERROR,");decimal(seq);putc_uart(',');text(reason);end_line();
}
static void ready(u32 seq) {
    text("READY,1,100000000,8,gui-v1,");decimal(seq);end_line();
}
static void execute(const u8 *p,u32 seq) {
    for(u32 i=0;i<8;++i) { a[i]=(i8)p[6+i]; b[i]=(i8)p[14+i]; }
    i32 expected=(i32)((u32)p[22]|((u32)p[23]<<8)|((u32)p[24]<<16)|((u32)p[25]<<24));
    LED_STATUS=0;
    u32 t0=now(); i32 sw=software_dot(); u32 t1=now();
    // Full MMIO transaction is timed; parsing, comparison and printing are not.
    u32 t2=now();
    for(u32 i=0;i<8;++i) {
        MMIO(0x40000020u+4*i)=(u32)(i32)a[i];
        MMIO(0x40000040u+4*i)=(u32)(i32)b[i];
    }
    CONTROL=1;
    u32 limit=10000;
    while(!(STATUS&2u)) if(--limit==0) { LED_STATUS=2;error(seq,"ACC_TIMEOUT");return; }
    i32 hw=(i32)RESULT;u32 t3=now();u32 compute=COMPUTE;
    u32 pass=sw==hw && hw==expected && compute==8;
    LED_STATUS=pass?1:2;
    text("RESULT,");decimal(seq);putc_uart(',');signed_decimal(sw);putc_uart(',');signed_decimal(hw);
    putc_uart(',');decimal(t1-t0);putc_uart(',');decimal(compute);putc_uart(',');decimal(t3-t2);
    text(pass?",PASS":",FAIL");end_line();
}
int main(void) {
    u8 packet[27];u32 used=0,last=now();
    ready(65535);
    for(;;) {
        u32 status=RX_STATUS;
        if(status&6u) {
            RX_STATUS=status&6u;
            while(RX_STATUS&1u) (void)RX_DATA;
            used=0;error(65535,(status&2u)?"FRAMING":"OVERRUN");continue;
        }
        if(!(status&1u)) {
            if(used && (u32)(now()-last)>RX_TIMEOUT) {used=0;error(65535,"TIMEOUT");}
            continue;
        }
        u8 c=(u8)RX_DATA;last=now();
        if(used==0) {if(c==0xa5) packet[used++]=c;continue;}
        if(used==1 && c!=0x5a) {used=(c==0xa5)?1:0;continue;}
        packet[used++]=c;
        if(used<27) continue;
        u32 seq=(u32)packet[4]|((u32)packet[5]<<8);
        u8 crc=0;for(u32 i=2;i<26;++i) crc=crc_step(crc,packet[i]);
        if(crc!=packet[26]) {
            error(seq,"CHECKSUM");
            // Retain a potential next packet embedded after a corrupt/truncated one.
            u32 start=1;while(start<26 && !(packet[start]==0xa5 && packet[start+1]==0x5a)) ++start;
            if(start<26) {used=27-start;for(u32 i=0;i<used;++i) packet[i]=packet[start+i];}
            else {used=packet[26]==0xa5?1:0;packet[0]=0xa5;}
            last=now();continue;
        }
        used=0;
        if(packet[2]!=1) error(seq,"VERSION");
        else if(packet[3]==0) ready(seq);
        else if(packet[3]==1) execute(packet,seq);
        else error(seq,"COMMAND");
    }
}
