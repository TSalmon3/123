$INCLUDE(REG52.INC)
$INCLUDE(SETTING.INC)

EXTERN CODE(MANAGE_SPEAKER);声音管理
EXTERN CODE(KEYSOUND);外部按键音程序
EXTERN CODE(OPEN_ALARM);打开闹钟警示音
EXTERN CODE(STOP_ALARM);关闭闹钟警示音

EXTERN CODE(SCAN_KEY4X4);外部4x4按键扫描程序
EXTERN DATA(O_KEY_4);返回的旧键值
EXTERN DATA(N_KEY_4);返回的新键值

EXTERN CODE(SCAN_KEY8X1);外部8x1按键扫描程序
EXTERN DATA(O_KEY_8);返回的旧键值
EXTERN DATA(N_KEY_8);返回的新键值

EXTERN CODE(DISP);外部显示子程序


A_SEC DATA 56H;ALARM SECOND
A_MIN DATA 57H;ALARM MINUTE 
A_HOU DATA 58H;ALARM HOUR



;HHOU DATA 5FH;12h/24H
SEC DATA 60H;second
MIN DATA 61H;minute
HOU DATA 62H;hour

COUNT1 DATA 65H ;定时器0计数单元
COUNT2 DATA 66H ;定时器0计数单元

COUNT4 DATA 67H ;定时器1计数单元


DAY DATA 50H;day
MON DATA 51H;month
YEL DATA 52H;year low byte
YEH DATA 53H;year high byte
DMAX DATA 55H;月份天数溢出量


PWORD DATA 20H  ;进程状态字（PROCESS STATUS WORD）
PMODE BIT 20H.0 ;工作模式位（0:normal, 1:setting)
FLASH BIT 20H.3 ;闪烁控制位（flash bit)
TOGGLE BIT 20H.4;12h/24h切换标志位
BF BIT 20H.5;是否在设置(BUZY FALG)

PROCESS DATA 21H;进程切换控制单元
COUNT3 DATA 23H;进程切换的计数单元
COUNT5 DATA 24H;进程切换的计数单元
CURSOR DATA 25H;修改位置指示单元

AWORD DATA 2EH;闹钟状态字（alarm status word）
ARUN BIT 2EH.0;闹钟运行标志位（alarm run bit)
AF BIT 2EH.1;到点溢出标志位(alarm flag bit)
COUNT6 DATA 2CH;恢复计数单元
COUNT7 DATA 2DH;恢复计数单元


CSEG AT 0000H
LJMP MAIN
CSEG AT 000BH
LJMP TIMER0
CSEG AT 001BH
LJMP TIMER1
CSEG AT 0030H
MAIN:
LCALL STARTUP;调用初始化
LOOP:
LCALL CZ;调用拆字
LCALL DISP;调用显示
LCALL SCAN_KEY4X4;调用按键扫描获取键值
LCALL SCAN_KEY8X1;调用按键扫描获取键值
LCALL MANAGE_4X4KEY;按键处理
LCALL MANAGE_8X1KEY;按键处理
LCALL MANAGE_SPEAKER;声音管理
LCALL MANAGE_PROCESS;进程管理
LJMP LOOP

;--------------------------------------------------------------------------------------------------------
;功能：初始化
;占用：无
;返回：无
;--------------------------------------------------------------------------------------------------------
STARTUP:
    ;初始化闹钟
    MOV A_SEC, #20H
    MOV A_MIN, #58H 
    MOV A_HOU, #23H 
    ;初始化时间
    MOV SEC, #01H
    MOV MIN, #58H
    MOV HOU, #23H
    MOV COUNT1, #00H
    MOV COUNT2, #00H

    MOV COUNT4, #00H
    ;初始化日期
    MOV DAY, #20H
    MOV MON, #11H
    MOV YEL, #99H
    MOV YEH, #20H;固定位
    MOV DMAX, #31H;对应月份最大天数

    ;初始化进程
    MOV PWORD, #00H;默认|normal模式|flash:false|toggle :false|bf:falsh|
    MOV PROCESS, #02H;默认日期进程
    MOV COUNT3, #00H;计数器清零
    MOV COUNT5, #00H;计数器清零
    MOV CURSOR, #01H;对应第一段数码管


    SETB P1.0;闹钟默认关闭
    MOV AWORD, #00H;默认|arun:false|af:false|
    ;初始化显存
    MOV 30H, #00H
    MOV 31H, #01H
    MOV 32H, #02H
    MOV 33H, #03H
    MOV 34H, #04H
    MOV 35H, #05H
    MOV 36H, #06H
    MOV 37H, #07H
    ;初始化无操作返回
    MOV COUNT6, #00H;无操作计数初值
    MOV COUNT7, #00H;无操作计数初值
    ;初始化堆栈
    MOV SP, #6FH
    ;初始化 8255A(PART 1)
    MOV A, #_8255A_AOBOCHICLI;取状态字
    MOV DPTR, #(0FE00H OR _8255A_CONTROL);取控制口地址
    MOVX @DPTR, A;写控制字

    ;初始化 8255A(PART 2)
    MOV A, #_8255A_AOBICHICLI;取状态字
    MOV DPTR, #(0FD00H OR _8255A_CONTROL);取控制口地址
    MOVX @DPTR, A;写控制字


    ;初始化定时器
    CLR TR1;关闭定时器1
    SETB TR0;打开定时器0
    SETB EA;打开总中断
    SETB ET0;打开定时器0中断
    SETB ET1;打开定时器1中断

    MOV TMOD, #12H;定时器0工作在方式2 定时器1工作在方式1
    MOV TH0, #00H; 100 X 36 X 256 X T = 10MS 
    MOV TL0, #00H;

    MOV TH1, #3CH; 50000 X T = 100ms 
    MOV TL1, #0B0H;
RET


;--------------------------------------------------------------------------------------------------------
;功能：拆字并格式化存储
;占用：R0, R1, DPTR, A
;返回：无
;--------------------------------------------------------------------------------------------------------
CZ:  
    ;格式化拆字
    JNB PROCESS.0, NPR0;01H 显示时间
        LCALL CZ1
        SJMP NPR2
    NPR0:JNB PROCESS.1, NPR1 ;02H 显示日期
        LCALL CZ2 
        SJMP NPR2 
    NPR1:JNB PROCESS.2, NPR2 ;04显示闹钟
        LCALL CZ3 
    NPR2:

    ;闪烁效果
    MOV R0, #32H;取第三块显存地址
    MOV R1, #34H;取第五块显存地址
    JB PROCESS.1, NP1;如果不是日期进程则继续
        ;位置调整
        INC R0 ;取第4块显存地址
        INC R1
        INC R1 ;取第7块显存地址
    NP1:

    JNB PMODE, CZRET;如果是设置模式则继续
        JNB FLASH, CZRET;如果闪烁则继续
            MOV A, CURSOR
            CJNE A, #01H, CZN1;如果是第一段数码管
                MOV 30H, #12H;第1块显存单元数码用空格覆盖
                SJMP CZRET
            CZN1: CJNE A, #02H, CZN2;如果是第二段
                MOV 31H, #12H;第2块显存单元数码用空格覆盖
                SJMP CZRET 
            CZN2: CJNE A, #04H, CZN3;如果是第三段
                MOV @R0, #12H ;第3块（第4块）
                SJMP CZRET 
            CZN3: CJNE A, #08H, CZN4;如果是第四段
                INC R0
                MOV @R0, #12H;第4块（第5块）
                SJMP CZRET 
            CZN4: CJNE A, #10H, CZN5;如果是第五段
                MOV @R1, #12H;第5块（第7块）
                SJMP CZRET
            CZN5: CJNE A, #20H, CZRET;如果是第六段
                INC R1
                MOV @R1, #12H;第6块（第8块）
CZRET:RET

CZ1:
    ;格式化拆字
    MOV R1, #60H;指向时间进程第一个待拆字
    MOV R0, #30H;指向第一块显存
    CZ1LOOP1:
        MOV A, @R1;取待拆字 
        ANL A, #0FH ;拆低位
        MOV @R0, A ;写入显存
        INC R0 ;指向下一个缓存单元

        MOV A, @R1;取待拆字节
        SWAP A 
        ANL A, #0FH;拆高位 
        MOV @R0, A ;写入显存
        INC R0 ;指向下一个缓存单元
        INC R0  ;指向下一个缓存单元
        INC R1 ;指向下一个待拆字节
        MOV A, R1
    CJNE A, #64H, CZ1LOOP1;如果还没拆完最后一个待拆字,拆下一个字
    MOV 32H, #10H;送“-”索引
    MOV 35H, #10H;送“-”索引
    ;12h/24h切换
    JB PMODE, CZ1RET;如果当前是normal mode则继续
        JNB TOGGLE, CZ1RET; 如果当前处于切换状态
            MOV R7, HOU;存小时压缩bcd码
            MOV A, HOU 
            CJNE A, #00H, NEQ0 ;如果小时为00H则00h转24h
                MOV R7, #24H ;00H转24h
            NEQ0:

            ;解压小时BCD码
            ;算法：高位*10+低位
            MOV A, R7 
            ANL A, #0F0H 
            SWAP A 
            MOV B, #10 
            MUL AB
            MOV B, A 
            MOV A, R7 
            ANL A, #0FH
            ADD A, B

            CLR C 
            SUBB A, #13
            JC CZ1RET;如果大于等于13点需要减12小时
                MOV DPTR, #ATAB;取调整小时表地址
                MOVC A, @A+DPTR;读对应12H时间制的小时值
                MOV R7, A;存12h制小时值
                
                ;对格式化拆字结果进行调整
                MOV A, R7 
                ANL A, #0FH 
                MOV 36H, A ; 写小时低位
                MOV A, R7 
                ANL A, #0F0H
                SWAP A 
                MOV 37H, A; 写小时高位
CZ1RET:RET

ATAB:;12H小时制 table
DB 01H, 02H, 03H, 04H, 05H, 06H, 07H, 08H, 09H, 10H, 11H, 12H

CZ2:
        MOV R1, #50H;指向日期进程第一个待拆字
        MOV R0, #30H;指向缓存单元首地址
        CZNEQ1:
        MOV A, @R1;取待拆字节
        ANL A, #0FH ;拆低位
        MOV @R0, A ;存储
        INC R0 ;指向下一个缓存单元

        MOV A, @R1 ;取待拆字节
        SWAP A 
        ANL A, #0FH ;拆高位
        MOV @R0, A 
        INC R0 ;指向下一个缓存单元
        INC R1 ;指向下一个待拆字节
        MOV A, R1
    CJNE A, #54H, CZNEQ1;判断是否已经拆完最后一个字节,如果是结束流程,否则继续拆下一个字
    ;格式化输出
    MOV A, MON
    ANL A, #0FH 
    ADD A, #13H;当前偏移量加13h
    MOV 32H, A 
    MOV A, YEL 
    ANL A, #0FH 
    ADD A, #13H ;当前偏移量加13h
    MOV 34H, A
RET

CZ3:
    MOV R1, #56H;指向时间进程第一个待拆字
    MOV R0, #30H
    CZNEQ2:
        MOV A, @R1;取待拆字节 
        ANL A, #0FH ;拆低位
        MOV @R0, A ;存储
        INC R0 ;指向下一个缓存单元

        MOV A, @R1;取待拆字节
        SWAP A 
        ANL A, #0FH;拆高位 
        MOV @R0, A 
        INC R0 ;指向下一个缓存单元
        INC R0  ;指向下一个缓存单元
        INC R1 ;指向下一个待拆字节
        MOV A, R1
    CJNE A, #59H, CZNEQ2;判断是否已经拆完最后一个字节,如果是结束流程,否则继续拆下一个字
    MOV 32H, #10H;送“-”索引
    MOV 35H, #10H;送“-”索引
RET
;--------------------------------------------------------------------------------------------------------
;功能：处理8x1BUTTONS
;占用：A, DPTR
;返回：无
;--------------------------------------------------------------------------------------------------------
MANAGE_8X1KEY:
    ;按键音
    MOV A, O_KEY_8 
    CJNE A, #0FFH, M88;如果原先按键没按下则继续
    MOV A, N_KEY_8 
    XRL A, #0FFH
    JZ M88              ;如果当前按键按下则继续
        SETB BF         ;有按键操作
        LCALL KEYSOUND  ;播放按键音
    M88:

    ;12h/24h切换
    MOV A, O_KEY_8
    CJNE A, #0FFH, M8 ;如果原先按键没按下则继续
    MOV A, N_KEY_8 
    CJNE A, #0FDH, M8 ;如果当前按键PB1按下则继续
        CPL TOGGLE; 12H/24H 切换
    M8:

    ;切换到闹钟进程
    MOV A, O_KEY_8
    CJNE A, #0FFH, M8RET ;如果原先按键没按下则继续
    MOV A, N_KEY_8
    CJNE A, #0FEH, M8RET ;如果当前按键PB1按下则继续
        JB PMODE, PR8NB; 如果处于正常模式则继续
            MOV PROCESS, #04H;切换到闹钟进程
        PR8NB:
M8RET:RET

;--------------------------------------------------------------------------------------------------------
;功能：处理4x4BUTTONS
;占用：A, DPTR, R0
;返回：无
;--------------------------------------------------------------------------------------------------------
MANAGE_4X4KEY:
    MOV A, O_KEY_4 
    CJNE A, #10H, UNPRESS ;如果原先按键没按下则继续
    MOV A, N_KEY_4
    XRL A, #10H 
    JZ UNPRESS ;如果当前有按键按下则继续
        SETB BF;有按键操作
        LCALL KEYSOUND ;调用按键音
        MOV A, N_KEY_4
        ADD A, N_KEY_4
        ADD A, N_KEY_4
        MOV DPTR, #KST
        JMP @A+DPTR ;以键号*3+首地址为地址进行跳转
UNPRESS:RET

    KST: ;key subroutine list 
    LJMP K0
    LJMP K1 
    LJMP K2
    LJMP K3
    LJMP K4 
    LJMP K5
    LJMP K6 
    LJMP K7
    LJMP K8
    LJMP K9 
    LJMP KA 
    LJMP KB 
    LJMP KC 
    LJMP KD 
    LJMP KE 
    LJMP KF

    K0:
    RET

    ;1
    K1:
        JNB PMODE, K1RET;JUMP IF NOT SETTING MODE
            LCALL PROCESS_K1   
    K1RET:RET 
    
    PROCESS_K1:
        JNB PROCESS.2, K1PN2;如果是当前显示的是闹钟则继续
            MOV R0, #A_SEC 
            SJMP K1PN1
        K1PN2: JNB PROCESS.0, K1PN0;如果是当前显示的是时间则继续
            MOV R0, #SEC
            SJMP K1PN1
        K1PN0: JNB PROCESS.1, K1PN1;如果是当前显示的是日期则继续
            MOV R0, #DAY  
        K1PN1:

        MOV A, CURSOR
            CJNE A, #01H, K1P1
                MOV A, @R0 
                ANL A, #0F0H 
                ORL A, #01H
                MOV @R0, A
                LJMP PK1RET
            K1P1: CJNE A, #02H, K1P2
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #10H
                MOV @R0, A 
                LJMP PK1RET
            K1P2: CJNE A, #04H, K1P3 
                INC R0 
                MOV A, @R0 
                ANL A, #0F0H 
                ORL A, #01H
                MOV @R0, A 
                LJMP PK1RET
            K1P3: CJNE A, #08H, K1P4
                INC R0
                JNB PROCESS.1, K1L1
                    MOV A, @R0 
                    ANL A, #0FH
                    CLR C 
                    SUBB A, #3
                    JNC PK1RET;个位小于3则继续
                K1L1:
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #10H
                MOV @R0, A 
                LJMP PK1RET
            K1P4: CJNE A, #10H, K1P5
                INC R0 
                INC R0 
                MOV A, @R0 
                ANL A, #0F0H 
                ORL A, #01H
                MOV @R0, A 
                LJMP PK1RET
            K1P5: CJNE A, #20H, PK1RET
                INC R0 
                INC R0
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #10H
                MOV @R0, A
    PK1RET:RET


    ;2
    K2:
        JNB PMODE, K2RET ;JUMP IF NOT SETTING MODE
            LCALL PROCESS_K2
    K2RET:RET 

    PROCESS_K2:
        JNB PROCESS.2, K2PN2 ;04H 显示闹钟
            MOV R0, #A_SEC
            SJMP K2PN1
        K2PN2: JNB PROCESS.0, K2PN0;01H 显示时间
            MOV R0, #SEC
            SJMP K2PN1
        K2PN0: JNB PROCESS.1, K2PN1 ;02H 显示日期
            MOV R0, #DAY 
        K2PN1:
        
        MOV A, CURSOR
        CJNE A, #01H, K2P1
        JNB PROCESS.1, K2L1
            MOV A, @R0 
            ANL A, #0F0H
            SWAP A 
            CLR C 
            SUBB A, #03
            JNC PK2RET;十位小于3则继续
        K2L1:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #02H
            MOV @R0, A 
            LJMP PK2RET
        K2P1: CJNE A, #02H, K2P2
            MOV A, @R0 
            ANL A, #0FH
            ORL A, #20H
            MOV @R0, A  
            LJMP PK2RET
        K2P2: CJNE A, #04H, K2P3 
            INC R0
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #02H
            MOV @R0, A 
            LJMP PK2RET
        K2P3: CJNE A, #08H, K2P4 
            INC R0
            JB PROCESS.1, K2L2
                MOV A, @R0 
                ANL A, #0FH 
                ORL A, #20H
                MOV @R0, A
            K2L2:
            LJMP PK2RET
        K2P4: CJNE A, #10H, K2P5
            INC R0
            INC R0
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #02H
            MOV @R0, A 
            LJMP PK2RET
        K2P5: CJNE A, #20H, PK2RET
            INC R0
            INC R0
            JB PROCESS.1, K2L3
                MOV A, @R0 
                ANL A, #0FH 
                CLR C 
                SUBB A, #04H 
                JNC PK2RET;个位小于4则继续
            K2L3:
            MOV A, @R0 
            ANL A, #0FH
            ORL A, #20H
            MOV @R0, A
    PK2RET:RET


    ;3
    K3:
        JNB PMODE, K3RET;JUMP IF NOT SETTING MODE
            LCALL PROCESS_K3
    K3RET:RET

    PROCESS_K3:
        JNB PROCESS.2, K3PN2;04H 显示闹钟
            MOV R0, #A_SEC
            SJMP K3PN1
        K3PN2: JNB PROCESS.0, K3PN0;01H 显示时间
            MOV R0, #SEC
            SJMP K3PN1
        K3PN0: JNB PROCESS.1, K3PN1 ;02H 显示日期
            MOV R0, #DAY 
        K3PN1:

        MOV A, CURSOR
        CJNE A, #01H, K3P1
            JNB PROCESS.1, K3L1
                MOV A, @R0 
                ANL A, #0F0H
                SWAP A 
                CLR C 
                SUBB A, #03
                JNC PK3RET;十位小于3
            K3L1:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #03H
            MOV @R0, A 
            LJMP PK3RET
        K3P1: CJNE A, #02H, K3P2
            JNB PROCESS.1, K3L2
                MOV A, @R0
                ANL A, #0FH  
                CLR C 
                SUBB A, #02H
                JNC PK3RET;个位小于2
            K3L2:
            MOV A, @R0 
            ANL A, #0FH
            ORL A, #30H
            MOV @R0, A  
            LJMP PK3RET
        K3P2: CJNE A, #04H, K3P3 
            INC R0
            JNB PROCESS.1, K3L4
                MOV A, @R0
                ANL A, #0F0H 
                SWAP A 
                CLR C 
                SUBB A, #01
                JNC PK3RET;十位小于1
            K3L4:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #03H
            MOV @R0, A 
            LJMP PK3RET
        K3P3: CJNE A, #08H, K3P4 
            INC R0
            JB PROCESS.1, K3L5
                MOV A, @R0 
                ANL A, #0F0H 
                ORL A, #03H
                MOV @R0, A
            K3L5:
            LJMP PK3RET
        K3P4: CJNE A, #10H, K3P5
            INC R0
            INC R0
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #03H
            MOV @R0, A 
            LJMP PK3RET
        K3P5: CJNE A, #20H, PK3RET
            INC R0 
            INC R0
            JNB PROCESS.1, K3L6
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #30H
                MOV @R0, A
            K3L6:
    PK3RET:RET


    K4:
    RET

    ;4
    K5:
        JNB PMODE, K5RET;JUMP IF NOT SETTING MODE
        LCALL PROCESS_K4
    K5RET:RET

    PROCESS_K4:
        JNB PROCESS.2, K5PN2;04H 显示闹钟
            MOV R0, #A_SEC
            SJMP K5PN1
        K5PN2: JNB PROCESS.0, K5PN0;01H 显示时间
            MOV R0, #SEC
            SJMP K5PN1
        K5PN0: JNB PROCESS.1, K5PN1 ;02H 显示日期
            MOV R0, #DAY 
        K5PN1:

        MOV A, CURSOR
        CJNE A, #01H, K5P1
            JNB PROCESS.1, K5L1
                MOV A, @R0 
                ANL A, #0F0H
                SWAP A 
                CLR C 
                SUBB A, #03
                JNC PK5RET;个位小于3
            K5L1:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #04H
            MOV @R0, A 
            LJMP PK5RET
        K5P1: CJNE A, #02H, K5P2  
            JB PROCESS.1, K5L2
                MOV A, @R0 
                ANL A, #0FH 
                ORL A, #40H
                MOV @R0, A
            K5L2:
            LJMP PK5RET
        K5P2: CJNE A, #04H, K5P3
            INC R0 
            JNB PROCESS.1, K5L3
                MOV A, @R0
                ANL A, #0F0H 
                SWAP A 
                CLR C 
                SUBB A, #01
                JNC PK5RET;十位小于1
            K5L3:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #04H
            MOV @R0, A 
            LJMP PK5RET
        K5P3: CJNE A, #08H, K5P4 
            INC R0
            JB PROCESS.1, K5L4
                MOV A, @R0 
                ANL A, #0FH 
                ORL A, #40H
                MOV @R0, A
            K5L4:
            LJMP PK5RET
        K5P4: CJNE A, #10H, K5P5
            INC R0
            INC R0
            JB PROCESS.1, K5L5
                MOV A, @R0
                ANL A, #0F0H
                SWAP A
                CLR C 
                SUBB A, #02H 
                JNC PK5RET;十位小于2
            K5L5:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #04H
            MOV @R0, A 
            LJMP PK5RET
        K5P5: CJNE A, #20H, PK5RET
            INC R0
            INC R0
            JNB PROCESS.1, K5L6
                MOV A, YEL 
                ANL A, #0FH
                ORL A, #40H
                MOV YEL, A
            K5L6:
    PK5RET:RET

    
    ;5
    K6:
        JNB PMODE, K6RET;JUMP IF NOT SETTING MODE
            LCALL PROCESS_K6
    K6RET:RET

    PROCESS_K6:
        JNB PROCESS.2, K6PN2;04 显示闹钟
            MOV R0, #A_SEC
            SJMP K6PN1
        K6PN2: JNB PROCESS.0, K6PN0;01H 显示时间
            MOV R0, #SEC
            SJMP K6PN1
        K6PN0: JNB PROCESS.1, K6PN1 ;02H 显示日期
            MOV R0, #DAY
        K6PN1:

        MOV A, CURSOR
        CJNE A, #01H, K6P1
            JNB PROCESS.1, K6L1
                MOV A, @R0 
                ANL A, #0F0H
                SWAP A 
                CLR C 
                SUBB A, #03
                JNC PK6RET;十位小于3
            K6L1:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #05H
            MOV @R0, A 
            LJMP PK6RET
        K6P1: CJNE A, #02H, K6P2
            JB PROCESS.1, K6L2 
                MOV A, @R0 
                ANL A, #0FH 
                ORL A, #50H
                MOV @R0, A
            K6L2:
            LJMP PK6RET
        K6P2: CJNE A, #04H, K6P3 
            INC R0
            JNB PROCESS.1, K6L3
                MOV A, @R0
                ANL A, #0F0H 
                SWAP A 
                CLR C 
                SUBB A, #01
                JNC PK6RET;个位小于1
            K6L3:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #05H
            MOV @R0, A 
            LJMP PK6RET
        K6P3: CJNE A, #08H, K6P4
            INC R0
            JB PROCESS.1, K6L4
                MOV A, @R0 
                ANL A, #0FH 
                ORL A, #50H
                MOV @R0, A
            K6L4: 
            LJMP PK6RET
        K6P4: CJNE A, #10H, K6P5
            INC R0
            INC R0
            JB PROCESS.1, K6L5
                MOV A, @R0
                ANL A, #0F0H
                SWAP A
                CLR C 
                SUBB A, #02H 
                JNC PK6RET;十位小于2
            K6L5:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #05H
            MOV @R0, A 
            LJMP PK6RET
        K6P5: CJNE A, #20H, PK6RET
            INC R0
            INC R0
            JNB PROCESS.1, K6L6
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #50H
                MOV @R0, A
            K6L6:
    PK6RET:RET
 
    ;6
    K7:
        JNB PMODE, K7RET;JUMP IF NOT SETTING MODE
            LCALL PROCESS_K7
    K7RET:RET

    PROCESS_K7:
        JNB PROCESS.2, K7PN2;04H 显示闹钟
            MOV R0, #A_SEC
            SJMP K7PN1
        K7PN2: JNB PROCESS.0, K7PN0;01H 显示时间
            MOV R0, #SEC
            SJMP K7PN1
        K7PN0: JNB PROCESS.1, K7PN1 ;02H 显示日期
            MOV R0, #DAY
        K7PN1:

        MOV A, CURSOR
        CJNE A, #01H, K7P1
            JNB PROCESS.1, K7L1
                MOV A, @R0 
                ANL A, #0F0H
                SWAP A 
                CLR C 
                SUBB A, #03
                JNC PK7RET; 十位小于3
            K7L1:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #06H
            MOV @R0, A 
            LJMP PK7RET
        K7P1: CJNE A, #02H, K7P2  
            LJMP PK7RET
        K7P2: CJNE A, #04H, K7P3 
            INC R0
            JNB PROCESS.1, K7L2
                MOV A, @R0
                ANL A, #0F0H 
                SWAP A 
                CLR C 
                SUBB A, #01
                JNC PK7RET;十位小于1
            K7L2:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #06H
            MOV @R0, A 
            LJMP PK7RET
        K7P3: CJNE A, #08H, K7P4
            INC R0   
            LJMP PK7RET
        K7P4: CJNE A, #10H, K7P5
            INC R0
            INC R0

            JB PROCESS.1, K7L3
                MOV A, @R0
                ANL A, #0F0H
                SWAP A
                CLR C 
                SUBB A, #02H 
                JNC PK7RET;十位小于2
            K7L3:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #06H
            MOV @R0, A 
            LJMP PK7RET
        K7P5: CJNE A, #20H, PK7RET
            INC R0 
            INC R0
            JNB PROCESS.1, K7L4
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #60H
                MOV @R0, A
            K7L4:
    PK7RET:RET


    K8:
    RET

    ;7
    K9:
        JNB PMODE, K9RET;JUMP IF NOT SETTING MODE
            LCALL PROCESS_K9
    K9RET:RET

    PROCESS_K9:
        JNB PROCESS.2, K9PN2;04H 显示闹钟
            MOV R0, #A_SEC
            SJMP K9PN1
        K9PN2: JNB PROCESS.0, K9PN0;01H 显示时间
            MOV R0, #SEC
            SJMP K9PN1
        K9PN0: JNB PROCESS.1, K9PN1 ;02H 显示日期
            MOV R0, #DAY 
        K9PN1:

        MOV A, CURSOR
        CJNE A, #01H, K9P1
            JNB PROCESS.1, K9L1
                MOV A, @R0 
                ANL A, #0F0H
                SWAP A 
                CLR C 
                SUBB A, #03
                JNC PK9RET;十位小于3
            K9L1:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #07H
            MOV @R0, A 
            LJMP PK9RET
        K9P1: CJNE A, #02H, K9P2  
            LJMP PK9RET
        K9P2: CJNE A, #04H, K9P3
            INC R0 
            JNB PROCESS.1, K9L2
                MOV A, @R0
                ANL A, #0F0H 
                SWAP A 
                CLR C 
                SUBB A, #01;十位小于1
                JNC PK9RET
            K9L2:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #07H
            MOV @R0, A 
            LJMP PK9RET
        K9P3: CJNE A, #08H, K9P4 
            INC R0
            LJMP PK9RET
        K9P4: CJNE A, #10H, K9P5
            INC R0 
            INC R0 

            JB PROCESS.1, K9L3
                MOV A, @R0
                ANL A, #0F0H
                SWAP A
                CLR C 
                SUBB A, #02H 
                JNC PK9RET;十位小于2
            K9L3:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #07H
            MOV @R0, A 
            LJMP PK9RET
        K9P5: CJNE A, #20H, PK9RET
            INC R0 
            INC R0
            JNB PROCESS.1, K9L4
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #70H
                MOV @R0, A
            K9L4:
    PK9RET:RET

    ;8
    KA:
        JNB PMODE, KARET;JUMP IF NOT SETTING MODE
            LCALL PROCESS_KA
    KARET:RET

    PROCESS_KA:
        JNB PROCESS.2, KAPN2;04H 显示闹钟
            MOV R0, #A_SEC
            SJMP KAPN1
        KAPN2: JNB PROCESS.0, KAPN0;01H 显示时间
            MOV R0, #SEC
            SJMP KAPN1
        KAPN0: JNB PROCESS.1, KAPN1 ;02H 显示日期
            MOV R0, #DAY
        KAPN1:

        MOV A, CURSOR
        CJNE A, #01H, KAP1
            JNB PROCESS.1, KAL1
                MOV A, @R0 
                ANL A, #0F0H
                SWAP A 
                CLR C 
                SUBB A, #03
                JNC PKARET;十位小于3
            KAL1:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #08H
            MOV @R0, A 
            LJMP PKARET
        KAP1: CJNE A, #02H, KAP2  
            LJMP PKARET
        KAP2: CJNE A, #04H, KAP3 
            INC R0
            JNB PROCESS.1, KAL2
                MOV A, @R0
                ANL A, #0F0H 
                SWAP A 
                CLR C 
                SUBB A, #01
                JNC PKARET;十位小于1
            KAL2:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #08H
            MOV @R0, A 
            LJMP PKARET
        KAP3: CJNE A, #08H, KAP4 
            INC R0
            LJMP PKARET
        KAP4: CJNE A, #10H, KAP5
            INC R0 
            INC R0 
            JB PROCESS.1, KAL3
                MOV A, @R0
                ANL A, #0F0H
                SWAP A
                CLR C 
                SUBB A, #02H 
                JNC PKARET;个位小于2
            KAL3:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #08H
            MOV @R0, A 
            LJMP PKARET
        KAP5: CJNE A, #20H, PKARET
            INC R0 
            INC R0
            JNB PROCESS.1, KAL4
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #80H
                MOV @R0, A
            KAL4:
    PKARET:RET


    ;9
    KB:
        JNB PMODE, KBRET;JUMP IF NOT SETTING MODE
            LCALL PROCESS_KB
    KBRET:RET

    PROCESS_KB:
        JNB PROCESS.2, KBPN2;04H 显示闹钟
            MOV R0, #A_SEC
            SJMP KBRET
        KBPN2: JNB PROCESS.0, KBPN0;01H 显示时间
            MOV R0, #SEC
            SJMP KBRET
        KBPN0: JNB PROCESS.1, KBPN1 ;02H 显示日期
            MOV R0, #DAY
        KBPN1:

        MOV A, CURSOR
        CJNE A, #01H, KBP1
            JNB PROCESS.1, KBL1
                MOV A, @R0 
                ANL A, #0F0H
                SWAP A 
                CLR C 
                SUBB A, #03
                JNC PKBRET;十位小于3
            KBL1:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #09H
            MOV @R0, A 
            LJMP PKBRET
        KBP1: CJNE A, #02H, KBP2 
            LJMP PKBRET
        KBP2: CJNE A, #04H, KBP3 
            INC R0
            JNB PROCESS.1, KBL2
                MOV A, @R0
                ANL A, #0F0H 
                SWAP A 
                CLR C 
                SUBB A, #01
                JNC PKBRET;十位小于1
            KBL2:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #09H
            MOV @R0, A 
            LJMP PKBRET
        KBP3: CJNE A, #08H, KBP4 
            INC R0
            LJMP PKBRET
        KBP4: CJNE A, #10H, KBP5
            INC R0 
            INC R0
            JB PROCESS.1, KBL3
                MOV A, @R0
                ANL A, #0F0H
                SWAP A
                CLR C 
                SUBB A, #02H 
                JNC PKBRET;十位小于2
            KBL3:
            MOV A, @R0 
            ANL A, #0F0H 
            ORL A, #09H
            MOV @R0, A 
            LJMP PKBRET
        KBP5: CJNE A, #20H, PKBRET
            INC R0 
            INC R0 
            JNB PROCESS.1, KBL4
                MOV A, @R0 
                ANL A, #0FH
                ORL A, #90H
                MOV @R0, A
            KBL4:
    PKBRET:RET

    KC:
    RET

    ;功能：处理按键*
    KD:
        JB PMODE, KDNN ;如果是normal mode 则继续

            JNB AF, KDNB;如果闹钟响则继续
                CLR AF ;关闭闹钟标志位
                LCALL STOP_ALARM;关闭闹钟
                SJMP KDRET
            KDNB:

            SETB PMODE;切换到setting mode
            JB PROCESS.2, DDD;如果不是闹钟进程则继续
                CLR TR0 ;关闭定时器0
            DDD:
            SETB TR1 ;打开定时器1
            MOV CURSOR, #01H
            SJMP KDRET
        KDNN:
            MOV A, CURSOR
            RL A 
            MOV CURSOR, A 
            CJNE A, #40H, KDRET
                MOV CURSOR, #01H
    KDRET:RET

    ;0
    KE:
        JB PMODE, KENN;JUMP IF NOT NORMAL MODE
            CPL ARUN;打开闹钟
            JNB ARUN, NOT_RUN; JUMP IF NOT OPEN ALARM CLOCK
                CLR P1.0;OPEN LED
                SJMP L1 
            NOT_RUN:;NOT OPEN ALARM CLOCK
                SETB P1.0;CLOSE LED 
                SJMP L1 
            L1:LJMP KERET
        KENN:;SETING MODE
            LCALL PROCESS_KE
    KERET:RET

    PROCESS_KE:
        JNB PROCESS.2, KEPN2;02H 显示闹钟 JUMP IF NOT ALARM CLOCK PROCESS
            MOV R0, #A_SEC
            SJMP KEPN1
        KEPN2: JNB PROCESS.0, KEPN0;01H 显示时间 JUMP IF NOT TIME PROCESS
            MOV R0, #SEC
            SJMP KEPN1
        KEPN0:JNB PROCESS.1, KEPN1 ;02H 显示日期 JUMP IF NOT DATE PROCESS
            MOV R0, #DAY 
        KEPN1:

        MOV A, CURSOR
        CJNE A, #01H, KEP1
            MOV A, @R0 
            ANL A, #0F0H 
            MOV @R0, A 
            LJMP PKERET
        KEP1: CJNE A, #02H, KEP2
            MOV A, @R0 
            ANL A, #0FH
            MOV @R0, A  
            LJMP PKERET
        KEP2: CJNE A, #04H, KEP3 
            INC R0 
            MOV A, @R0 
            ANL A, #0F0H 
            MOV @R0, A 
            LJMP PKERET
        KEP3: CJNE A, #08H, KEP4
            INC R0 
            MOV A, @R0 
            ANL A, #0FH
            MOV @R0, A 
            LJMP PKERET
        KEP4: CJNE A, #10H, KEP5
            INC R0 
            INC R0 
            MOV A, @R0 
            ANL A, #0F0H 
            MOV @R0, A 
            LJMP PKERET
        KEP5: CJNE A, #20H, PKERET
            INC R0 
            INC R0 
            MOV A, @R0 
            ANL A, #0FH
            MOV @R0, A
    PKERET:RET


    ;功能：处理按键#
    KF:
        JB PMODE, KFNN; JMP IF NOT NOTMAL MODE
            MOV COUNT3, #00H;重新计数 
            MOV COUNT5, #00H;重新计数
            LCALL PROCESS_SWITCH
            LJMP KERET
        KFNN: ;SETTING MODE
            JNB PROCESS.2, KFNP2 ;JMP IF NOT ALARM CLOCK PROCESS
                MOV PROCESS, #01H;返回时间进程
                CLR PMODE;返回normal mode
                CLR TR1 ;关闭控制闪烁定时器 
                LJMP KERET
            KFNP2: ;DATE PROCESS AND TIME PROCESS
                LCALL GET_DMAX;获取Dmax

                ;天数调整
                MOV A, DAY
                SETB C 
                SUBB A, DMAX 
                JC KFL1 ;如果天数超过最大天数
                    MOV DAY, DMAX 
                KFL1:
                CLR PMODE;返回normal mode
                CLR TR1 ;关闭控制闪烁定时器
                SETB TR0;打开控制进程切换定时器
    KFRET:RET

;--------------------------------------------------------------------------------------------------------
;功能：进程管理
;占用
;--------------------------------------------------------------------------------------------------------
MANAGE_PROCESS:
    LCALL MANAGE_SWITCH
    LCALL MANAGE_RECOVER
RET

;--------------------------------------------------------------------------------------------------------
;功能：进程的切换
;占用：A
;返回：无
;--------------------------------------------------------------------------------------------------------
MANAGE_SWITCH:
    JB PMODE, MPRET; jump if setting mode
        INC COUNT3;当前进程运行计数单元加一
        MOV A, COUNT3
        CJNE A, #245, MPRET
            MOV COUNT3, #00H 
            INC COUNT5
            MOV A, COUNT5 
        CJNE A, #3, MPRET 
            MOV COUNT5, #00H;进程计数单元清零
            LCALL PROCESS_SWITCH;切换进程单元
MPRET:RET

;--------------------------------------------------------------------------------------------------------
;功能：无操作复原
;占用：A
;返回：无
;--------------------------------------------------------------------------------------------------------
MANAGE_RECOVER:
    JNB PMODE, MRRET ;jump if NOT SETTING MODE
        JNB BF, MRNS ;JUMP IF NOT PRESS KEY
            MOV COUNT6, #00H
            MOV COUNT7, #00H
            SJMP MRRET
        MRNS:
            INC COUNT6 
            MOV A, COUNT6
            CJNE A, #250, MRRET
                MOV COUNT6, #00H
                INC COUNT7
                MOV A, COUNT7 
            CJNE A, #10, MRRET
                ;日期错误处理
                JNB PROCESS.1, MRL1
                    LCALL GET_DMAX;获取Dmax
                    ;天数调整
                    MOV A, DAY
                    SETB C 
                    SUBB A, DMAX 
                    JC MRL1 ;如果天数超过最大天数
                        MOV DAY, DMAX 
                MRL1:
                
                MOV COUNT7, #00H 
                CLR PMODE;return TO normal mode
    MRRET:CLR BF
RET

;--------------------------------------------------------------------------------------------------------
;功能：进程切换core
;占用：无
;返回：无
;--------------------------------------------------------------------------------------------------------
PROCESS_SWITCH:
    JNB PROCESS.0, PS0;判断process单元是否不等于01H, 如果不是则间跳
        MOV PROCESS, #02H;如果是则process单元赋值01H
        SJMP PSRET
    PS0: JNB PROCESS.1, PS1 ;判断process单元是否不等于02H, 如果不是则间跳
        MOV PROCESS, #01H;如果是则process单元赋值02H
        SJMP PSRET
    PS1:JNB PROCESS.2, PS2
        MOV PROCESS, #02H
        SJMP PSRET
    PS2:
        MOV PROCESS, #01H
PSRET:RET

;--------------------------------------------------------------------------------------------------------
;功能：闪烁频率调整
;占用：A, DPTR
;返回：无
;--------------------------------------------------------------------------------------------------------
TIMER1:
    PUSH ACC
    PUSH DPH 
    PUSH DPL 
    MOV TH1, #3CH; 50000 X T = 100ms 
    MOV TL1, #0B0H;
    INC COUNT4
    MOV A, COUNT4  
    CJNE A, #10, T1RET
        MOV COUNT4, #00H;时间片用完
        CPL FLASH;
    T1RET:
    POP DPL 
    POP DPH
    POP ACC
RETI

;--------------------------------------------------------------------------------------------------------
;功能：实时时间
;占用：dptr, acc, b, r0, psw
;返回：无
;--------------------------------------------------------------------------------------------------------
;功能：实时时间
TIMER0:
    PUSH ACC;保护累加器 
    PUSH PSW;保护psw
    PUSH DPL
    PUSH DPH
    PUSH B

    INC COUNT1;计数单元1加1
    MOV A, COUNT1;
    CJNE A, #36, T0RET;计数器1累计了36
    MOV COUNT1, #00H;计数器1清零
    INC COUNT2;计数器1加加 
    MOV A, COUNT2
    ;CJNE A, #100, T0RET;计数器2累计了100
    CJNE A, #20, T0RET;调试加速
    MOV COUNT2, #00H;计数器2清零

    LCALL ADJUST_TIME;时间调整
    LJMP TEST
    MOV A, SEC
    CJNE A, #00H, NOT_NEWDAY; (NOT NEW DAY)
    MOV A, MIN 
    CJNE A, #00H, NOT_NEWDAY 
    MOV A, HOU 
    CJNE A, #00H, NOT_NEWDAY
        TEST:
        LCALL ADJUST_DATE; 当时分秒为00:00:00时为新的一天
    NOT_NEWDAY:

    JNB ARUN, NOT_OPENALARM; 如果闹钟运行位为真则继续 (NOT OPEN ALARM CLOCK)
        MOV A, SEC 
        CJNE A, A_SEC, NOT_OPENALARM
            MOV A, MIN 
        CJNE A, A_MIN, NOT_OPENALARM
            MOV A, HOU
        CJNE A, A_HOU, NOT_OPENALARM
            LCALL OPEN_ALARM;如果时间与设定的闹钟时间相等就打开闹钟
            SETB AF;闹钟标志位置1
    NOT_OPENALARM:


    T0RET:
    POP B
    POP DPH
    POP DPL 
    POP PSW;复位psw
    POP ACC;复位累加器
RETI
;--------------------------------------------------------------------------------------------------------
;功能：获取当前月份的天数溢出值
;占用：A, B, DPTR
;返回：DMAX
;--------------------------------------------------------------------------------------------------------
GET_DMAX:
    ;月份压缩BCD解压
    ;算法：高位*10 + 低位
    MOV A, MON;读当前月份
    ANL A, #0F0H;屏蔽低位
    SWAP A;高低位交换
    MOV B, #10;
    MUL AB;十位乘10
    MOV B, A 
    MOV A, MON;读当前月份
    ANL A, #0FH;屏蔽高位
    ADD A, B;高位*10 + 低位

    ;以月份值为偏移量读天数溢出量
    MOV DPTR, #(DTAB-1);取月份天数表地址
    MOVC A, @A+DPTR;读天数溢出值
    MOV DMAX, A;存天数溢出值


    ;判断当前月份是否是二月，并对天数进行调整
    MOV A, MON
    CJNE A, #02H, NF;如果是二月则继续(not february)
        ;低位年分压缩bcd码解压
        ;算法：高位*10 + 低位
        MOV A, YEL
        SWAP A
        ANL A, #0FH
        MOV B, #10H
        MUL AB 
        MOV B, A 
        MOV A, YEL 
        ANL A, #0FH 
        ADD A, B
        

        ;判断是否闰年 （判断是否能被4整除）
        ;算法：低位年分解压的bcd码能别4整除
        MOV B, #4 
        DIV AB
        MOV A, B 
        ;CLR LEAP;默认不是闰年
        CJNE A, #00H, NLEAP;如果余数为0为闰年（not leap year)
            MOV A, DMAX
            ADD A, #01H 
            DA A 
            MOV DMAX, A 
        NLEAP:
    NF:
RET

;--------------------------------------------------------------------------------------------------------
;功能：时间调整
;占用：A
;返回：无
;--------------------------------------------------------------------------------------------------------
ADJUST_TIME:
    MOV A, SEC 
    ADD A, #01H
    DA A 
    MOV SEC, A;秒数加1
    CJNE A, #60H, ATRET;判断秒数是否累计到60 
    MOV SEC, #00H;秒数清零

    MOV A, MIN 
    ADD A, #01H
    DA A 
    MOV MIN, A;分钟加1
    CJNE A, #60H, ATRET;判断分钟是否累计到60 
    MOV MIN, #00H;分钟清零 

    MOV A, HOU
    ADD A, #01H
    MOV HOU, A ;小时加1
    CJNE A, #24H, ATRET ;判断小时数是否累计到24
    MOV HOU, #00H;小时数清零
ATRET:RET ;(adjust time return)

;--------------------------------------------------------------------------------------------------------
;功能：日期调整
;占用：A, B
;返回：无
;--------------------------------------------------------------------------------------------------------
ADJUST_DATE:
    LCALL GET_DMAX;获取Dmax
    ;日期调整
    MOV A, DMAX 
    ADD A, #01H 
    DA A 
    MOV B, A

    MOV A, DAY 
    ADD A, #01H 
    DA A 
    MOV DAY, A;天数加1
    CJNE A, B, ADRET;判断天数是否越界 
    MOV DAY, #01H ;天数置1

    MOV A, MON 
    ADD A, #01H
    DA A 
    MOV MON, A;月份加1
    CJNE A, #13H, ADRET;判断月份是否越界
    MOV MON, #01H ;月数置1

    MOV A, YEL
    ADD A, #01H 
    DA A 
    MOV YEL, A;加一年 2099年越界时自动溢出为2000年
ADRET:
    RET ;(adjust date return)
    ;对应月份的天数
    DTAB:
    DB 31H, 28H, 31H, 30H, 31H, 30H
    DB 31H, 31H, 30H, 31H, 30H, 31H 

END