$INCLUDE(REG52.INC)
NAME SPEAKER

DURATION_KEY EQU 8H
DURATION_CLOCK EQU 14H


TIMER DATA 4EH
TIMER1 DATA 4FH

SWORD DATA 2FH;声音状态字SPEAKER STATUS WORD
PLAYK BIT 2FH.0;按键音播放标志位
PLAYC BIT 2FH.1;闹钟音播放标志位
 
PUBLIC KEYSOUND
PUBLIC OPEN_ALARM
PUBLIC STOP_ALARM
PUBLIC MANAGE_SPEAKER


KEYSOUND?SPEAKER SEGMENT CODE 
MANAGE_SPEAKER?SPEAKER SEGMENT CODE 
OPEN_ALARM?SPEAKER SEGMENT CODE 
STOP_ALARM?SPEAKER SEGMENT CODE 

;--------------------------------------------------------------------------------------------------------
;功能：播放按键音
;占用：无
;返回：无
;--------------------------------------------------------------------------------------------------------
RSEG KEYSOUND?SPEAKER
KEYSOUND:
    SETB PLAYK;按键音播放标志位置1
    MOV TIMER, #00H;定时器置初值
RET


;--------------------------------------------------------------------------------------------------------
;功能：打开闹钟
;占用：无
;返回：无
;--------------------------------------------------------------------------------------------------------
RSEG OPEN_ALARM?SPEAKER
OPEN_ALARM:
    SETB PLAYC;闹钟音播放标志位置1
    MOV TIMER1, #00H;计数器清零
    CLR P3.2;开蜂鸣器
RET

 ;--------------------------------------------------------------------------------------------------------
;功能：关闭闹钟
;占用：P3.2
;返回：无
;--------------------------------------------------------------------------------------------------------
RSEG STOP_ALARM?SPEAKER
STOP_ALARM:
    CLR PLAYC;闹钟音播放标志位清0
    SETB P3.2;关蜂鸣器
RET

;--------------------------------------------------------------------------------------------------------
;功能：蜂鸣器管理
;占用：P3.2, A
;返回：无
;--------------------------------------------------------------------------------------------------------
RSEG MANAGE_SPEAKER?SPEAKER
MANAGE_SPEAKER:
    LCALL MANAGE_KEY;对按键音的管理
    LCALL MANAGE_CLOCK;对闹钟音的管理
RET

MANAGE_KEY:
    JNB PLAYK, MKRET;是否开始播放按键音 JUMP IF NOT PLAY
        CLR P3.2;开蜂鸣器
        INC TIMER;计数值加1
        MOV A, TIMER
        CJNE A, #DURATION_KEY, MKRET;判断计数值是否到达要求时间
            MOV TIMER, #00H;计数器清零
            CLR PLAYK;按键音标志位清零
            SETB P3.2;关闭蜂鸣器
MKRET:RET

MANAGE_CLOCK:
    JNB PLAYC, MCRET;是否播放闹钟音 jump if not play
        INC TIMER1 ;计数值加1
        MOV A, TIMER1 
        CJNE A, #DURATION_CLOCK, MCRET;判断计数值是否到达要求时间
            MOV TIMER1, #00H;计数器清零
            CPL P3.2;取反
MCRET:RET


END