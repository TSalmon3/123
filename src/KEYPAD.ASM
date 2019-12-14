$INCLUDE(REG52.INC)
$INCLUDE(SETTING.INC)

NAME KEYPAD

PUBLIC SCAN_KEY4X4
PUBLIC O_KEY_4
PUBLIC N_KEY_4
PUBLIC SCAN_KEY8X1
PUBLIC O_KEY_8
PUBLIC N_KEY_8


SCAN_KEY4X4?KEYPAD SEGMENT CODE
SCAN_KEY8X1?KEYPAD SEGMENT CODE


;4X4_KEY
BUFF DATA 40H ;BUFFER
SMP3_4 DATA 41H ;SAMPLE 3RD
SMP2_4 DATA 42H ;SAMPLE 2ND
SMP1_4 DATA 43H ;SAMPLE 1ST
N_KEY_4 DATA 44H ;NEW KEY CODE
O_KEY_4 DATA 45H ;OLE KEY CODE

;8X1_KEY
SMP5_8 DATA 46H ;SAMPLE 5TH
SMP4_8 DATA 47H ;SAMPLE 4TH
SMP3_8 DATA 48H ;SAMPLE 3RD
SMP2_8 DATA 49H ;SAMPLE 2ND
SMP1_8 DATA 4AH ;SAMPLE 1ST
N_KEY_8 DATA 4BH;NEW KEY CODE
O_KEY_8 DATA 4CH;OLE KEY CODE



RSEG SCAN_KEY8X1?KEYPAD
;--------------------------------------------------------------------------------------------------------
;功能：对8x1按键进行采样
;占用：DPTR, A
;返回：旧值（O_KEY_8）与新值（N_KEY_8）
;--------------------------------------------------------------------------------------------------------
SCAN_KEY8X1:
	MOV O_KEY_8, N_KEY_8;原新态存为旧态
	MOV SMP1_8, SMP2_8;更新最近5次采样
	MOV SMP2_8, SMP3_8;
	MOV SMP3_8, SMP4_8;
	MOV SMP4_8, SMP5_8;

	MOV DPTR, #(0FD00H OR _8255A_PORTB);取8255A的B口地址
	MOVX A, @DPTR;读B口电平
	MOV SMP5_8, A;存为第五次采样

	CJNE A, SMP4_8, GIVEUP8;判断最近5次采样是否相等
	CJNE A, SMP3_8, GIVEUP8
	CJNE A, SMP2_8, GIVEUP8
	CJNE A, SMP1_8, GIVEUP8
	MOV N_KEY_8, A;
GIVEUP8:RET



RSEG SCAN_KEY4X4?KEYPAD
;--------------------------------------------------------------------------------------------------------
;功能：对4x4按键进行采样
;占用：A, DPTR, R0, R1
;返回：旧值（O_KEY_4）与新值（N_KEY_4）
;--------------------------------------------------------------------------------------------------------
SCAN_KEY4X4:
	;滚动滤波
	MOV O_KEY_4, N_KEY_4;原新态存为旧态
	MOV SMP1_4, SMP2_4;更新最近3次采样
	MOV SMP2_4, SMP3_4;

	MOV A, #_8255A_AOBOCHICLO;C口高位输入,C口低位输出
	MOV DPTR, #(0FE00H OR _8255A_CONTROL);取8255A的控制口地址
	MOVX @DPTR, A;往控制口写状态字
	
	MOV A, #00H
	MOV DPTR, #(0FE00H OR _8255A_PORTC);取8255A的C口地址
	MOVX @DPTR, A;往C口写零
	MOVX A, @DPTR;读C口状态
	ANL A, #0F0H;屏蔽低位
	MOV BUFF, A;存行码
	
	MOV A, #_8255A_AOBOCHOCLI;C口高位输出,C口低位输入
	MOV DPTR, #(0FE00H OR _8255A_CONTROL);取8255A的控制口地址
	MOVX @DPTR, A;往控制口写状态字
	
	MOV A, #00H
	MOV DPTR, #(0FE00H OR _8255A_PORTC);取8255A的C口地址
	MOVX @DPTR, A;往C口写零
	MOVX A, @DPTR;读C口状态
	ANL A, #0FH ;屏蔽高位
	ORL A, BUFF;拼接行列码
	MOV BUFF, A;存储行列码

	MOV R0, #00H;取初始键号00h 
	MOV DPTR, #KTAB;取键码表地址 
	SKL1:
	MOV SMP3_4, R0;存键号
	MOV A, R0;取键号 
	MOVC A, @A+DPTR;读当前键号对应的键码 
	MOV R1, A;临时存键码
	XRL A, #0FFH 
	JZ SKF; 如果查到0ffh结束查表 FINISH
	MOV A, R1
	INC R0;取下一个键号
	CJNE A, BUFF, SKL1;如果键码与行列码相等结束查表
	SKF:


	MOV A, SMP3_4 
	CJNE A, SMP2_4, GIVEUP ;判断最近3次采样是否采样
	CJNE A, SMP1_4, GIVEUP ;
	MOV N_KEY_4, A ;第三次采样键码赋值给新键码
GIVEUP:RET

;key code table
KTAB:
	DB 0EEH,0EDH,0EBH,0E7H	;键码表。K0,K1,K2,K3键码
	DB 0DEH,0DDH,0DBH,0D7H	;K4,K5,K6,K7键码
	DB 0BEH,0BDH,0BBH,0B7H	;K8,K9,K10,K11键码
	DB 7EH,7DH,7BH,77H,0FFH;K12,K13,K14,K15键码 end of table(NORMAL, MULTI_PRESSED)

END