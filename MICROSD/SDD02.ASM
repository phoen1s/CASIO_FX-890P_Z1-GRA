;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;TITLE     : SDCard Device Driver for FX-890P V2.00
;FILE NAME : SDD02.ASM
;DATE      : 2022/03/10
;UPDATE    : 
;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
;==============================================================================
;###### Macro Definition Area #################################################
;------ SDCardComand ---------------
CMD0            EQU     40H             ; SD Comand = Go Idle State
CMD1            EQU     41H             ; SD Comand = Send Op CND
CMD9            EQU     49H             ; SD Comand = Send CSD
CMD10           EQU     4AH             ; SD Comand = Send CID
CMD16           EQU     50H             ; SD Comand = Set BlockLen
CMD17           EQU     51H             ; SD Comand = Read Single Block
CMD18           EQU     52H             ; SD Comand = Read Multiple Block
CMD24           EQU     58H             ; SD Comand = Write Block

;------ Drive Control code -------------
PT_STB          EQU     01H             ; STB Line Control
PT_RTS          EQU     04H             ; RTS Line Control
PT_DTR          EQU     08H             ; DTR Line Control

;------ Bios Code ----------------------
DBIS_SNTHIGHT   EQU     2AH             ; BIOS No = 2AH Centronics Line Hight
DBIS_SNTLOW     EQU     2BH             ; BIOS No = 2BH Centronics Line Low
DBIS_SNTREAD    EQU     2CH             ; BIOS No = 2CH Centronics Line Read

;------ SD Control NUM  ----------------
DA_TOKEN        EQU     0FEH
TIMEOUT         EQU     0008H
DUMMY_DT        EQU     0FFH

;------ Device Driver EQU ----------------------
POINT           EQU     12              ;FILE-POINTER
O_LOCK          EQU     20              ;OPEN-LOCK FLAG
PATH_P          EQU     21              ;PATH POINTER
S_HANDL         EQU     33              ;SERVER HANDLE
S_POINT         EQU     34              ;SERVER FILE-POINTER
DIR_NO          EQU     36              ;SERCH DIRECTORY No

P_MAX           EQU     27              ;DEVICE PAKET MAXIMUM

HNDNUM          EQU     16              ;HANDLE NUM
HNDANM          EQU     20              ;HANDLE AREA NUM
;==============================================================================
;###### Program Area ##########################################################
;===== ASSEMBLER HEADER =====

	.186
	.MODEL	SMALL

CODE	SEGMENT
	ASSUME	CS:CODE,DS:CODE,ES:CODE

	ORG	0000H

;===== DEVICE HEADER =====

START:
	DW	0000H			;DRIVE DEVICE
	DW	START			;START OFFSET
	DW	SELECTER		;MAIN ROUTINE
	DB	'SMDRV  '		;DEVICE NAME


;===== COMMAND PAKET TABLE =====

CP_TABLE:
	DW	INIT			;DEVICE INITIALIZE
	DW	EXIT			;INPUT-BUFFER CLEAR
	DW	EXIT			;INPUT-BUFFER CHECK
	DW	CHAR_INP		;1 CHAR INPUT
	DW	EXIT			;NO USE
	DW	BLOCK_INP		;DATA INPUT
	DW	EXIT			;DIRECT IN-OUT
	DW	EXIT			;OUTPUT-BUFFER CLEAR
	DW	EXIT			;OUTPUT-BUFFER CHECK
	DW	BLOCK_OUT		;DATA OUTPUT
	DW	OPEN			;FILE OPEN
	DW	CLOSE			;FILE CLOSE

	DW	EXIT			;NO USE
	DW	EXIT			;NO USE
	DW	EXIT			;NO USE

	DW	CREATE			;FILE CREATE  *** DRIVE DEVICE ONLY ***
	DW	DELETE			;FILE DELETE
	DW	RENAME			;FILE RENAME
	DW	SEARCH			;DIRECTORY SEARCH
	DW	STATUS_GET		;FILE STATUS GET
	DW	DATETIME		;DATE & TIME SET
	DW	ATTRIB_SET		;ATTRIBUTES SET
	DW	ONLINE			;DRIVE ONLINE CHECK
	DW	D_SPACE			;DISK SPACE GET
	DW	FORMAT			;DISK FORMAT
	DW	SD_SRCH			;SUB-DIRECTORY SEARCH
	DW	EXIT			;SUB-DIRECTORY MAKE
	DW	EXIT			;SUB-DIRECTORY DELETE

;===== PAKET =====

PAKET:
PAKET_NO	DB	0
PAKET_STATUS	DB	0
PAKET_FCB	DW	0,0
PAKET_DTA	DW	0,0
PAKET_COUNT	DW	0
		DB	4 DUP(0)

DIR:
DIR_ATTR	DB	0
DIR_TIME	DW	0
DIR_DATE	DW	0
DIR_SIZEL	DW	0
DIR_SIZEH	DW	0


;===== PAKET SELECTER =====

SELECTER:
	PUSH	DX
	PUSH	SI
	PUSH	DS
	PUSH	ES
	PUSH	BX
	CLD

	PUSH	ES			;PAKET COPY
	POP	DS
	PUSH	CS
	POP	ES
	MOV	SI,BX
	MOV	DI,OFFSET PAKET
	MOV	CX,12
	REP MOVSB
	PUSH	CS
	POP	DS

	MOV	AL,[PAKET_NO]		;PAKET CHECK
	CMP	AL,P_MAX+1
	JNC	SEL_JP2
	XOR	AH,AH
	ADD	AX,AX
	MOV	SI,AX
	JZ	SEL_JP1
	CMP	AL,22*2			;IF AL<>(ONLINE CHECK) THEN ->AUX_OPEN
	JZ	SEL_JP1
SEL_JP1:
        ;セントロニクス線初期化
        MOV     BL,0AH
        MOV     AH,2BH
        INT     41H
        MOV     BL,0DH;05H
        MOV     AH,2AH
        INT     41H
        CLI;割り込み禁止

	JMP	WORD PTR [SI][CP_TABLE] ; パケットテーブルへ。各ルーチンの処理
                                        ; 終了後はその処理に応じて以下のexit処
                                        ; 理へ飛ぶ
;------ Error Eexit Proc ---------------
SEL_JP2:
	MOV	AL,5
ERR_EXIT:
	MOV	CS:[PAKET_COUNT],0
	POP	DI
	POP	ES
	CALL	DRV_CLOSE               ; ドライブ終了ルーチンを入れる
	POP	DS
	POP	SI
	POP	DX
	MOV	AH,5			;Cannot access
	AND	AL,AL
	JZ	ERR_E_JP1
	CMP	AL,0FFH
	JZ	ERR_E_JP1
	MOV	AH,8			;Disk full
	CMP	AL,12
	JZ	ERR_E_JP1
	MOV	AH,15			;Invalid drive
	CMP	AL,10
	JZ	ERR_E_JP1
	MOV	AH,AL
ERR_E_JP1:
        STI;割り込み許可
	MOV	AL,AH
	XOR	AH,AH
	STC				;ERROR!!
	RETF

;------ Exit Proc ----------------------
EXIT:
	OR	CS:[PAKET_STATUS],80H
EXIT2:
        STI;割り込み許可
	POP	DI
	POP	ES
	CALL	DRV_CLOSE               ; ドライブ終了ルーチンを入れる
	POP	DS
	POP	SI
	POP	DX
	CLC
	RETF				;>DOS SYSTEM


;=============================
;===== DEVICE INITIALIZE =====

INIT:
	MOV	DX,OFFSET TITLE_MSG
	MOV	AH,9
	INT	21H

	LES	DI,DWORD PTR [PAKET_DTA] ;*** PARAMETER CHECK ***
	PUSH	ES
	POP	DS
	MOV	CX,0FFFFH
	MOV	AL,13
	PUSH	DI
	REPNZ SCASB
	NOT	CX			;PARAMETER LENGS
	POP	DI
; オプション設定
INI_LP1:
	MOV	AL,'/'
	REPNZ SCASB
	JNZ	INI_JP12
	MOV	SI,DI
	MOV	AX,ES:[DI]

	CMP	AL,'D'
	JZ	INI_JP1
	CMP	AL,'d'
	JZ	INI_JP1
	JMP	INI_JP10
INI_JP12:
	JMP	INI_JP11

INI_JP1:
	CMP	AH,'='
	JZ	INI_JP2
	JMP	INI_JP10
INI_JP2:
	ADD	DI,2
	MOV	AX,ES:[DI]
	CMP	AL,'E'
	JZ	INI_JP3
	CMP	AL,'e'
	JZ	INI_JP3
	JMP	INI_JP10
INI_JP3:
	SUB	AH,'0'
	CMP	AH,6			;DRIVE ERROR
	JNC	INI_JP10
	ADD	AH,10
	MOV     CS:[DRIVENO],AH
	JMP	INI_JP10

INI_JP10:				;OPTION ERASE
	MOV	DI,SI
	JMP	INI_LP1

INI_JP11:				;SETUP
	MOV	AX,CS
	MOV	DS,AX
	MOV	DX,OFFSET TITLE_MSG2
	MOV	AH,9
	INT	21H
	MOV	AL,DRIVENO
	ADD	AL,'0'-10
	INT	29H
	MOV	AL,':'
	INT	29H
	MOV	AL,13
	INT	29H
	MOV	AL,10
	INT	29H

;------ Driver init --------------------
        PUSH    CS
        POP     DS
        XOR     AL,AL
        MOV     SMFLAG,AL               ; フラグリセット

        PUSH    CS
        POP     ES
        MOV     CX,10
        MOV     DI,OFFSET HANDLE        ; ハンドルを初期化
        XOR     AX,AX
        REP     STOSB
        MOV     CX,320
        MOV     DI,OFFSET FADDRE        ; open情報の初期化
        REP     STOSB
        MOV     SDCLUS,AX               ; SDのクラスタ初期化
        MOV     CX,256
        MOV     DI,OFFSET PATHBUF       ; パスの初期化
        REP     STOSB

        XOR     AX,AX
        MOV     FATUSEN,AX              ; 空き容量キャッシュクリア
        MOV     AX,0FFFFH
        MOV     FATFEN,AX               ; 一番若いFATクラスタ初期化

	POP	DI
	POP	ES
	POP	DS
	POP	SI
	POP	DX
	CLC
	RETF

;===== 1 CHAR INPUT =====

CHAR_INP:
; ----- 現状未対応 ------
	MOV	AX,0001H		; Invalid Function Code
	JMP	ERR_EXIT

;===== DATAS INPUT =====

BLOCK_INP:
        LES     BX,DWORD PTR [PAKET_FCB]
        MOV     AL,ES:[BX][S_HANDL]
        CALL    C_FHAND                 ; ハンドルチェック
        JC      BLO_IS_JP0
        MOV     AL,6                    ;Invalid handle
        JMP     ERR_EXIT
BLO_IS_JP0:
        CALL    P_MOVE                  ; 入力されてきたポインタまで移動

        MOV     AL,ES:[BX][S_HANDL]     ; ハンドル取得
        MOV     AH,HNDANM
        MUL     AH
        MOV     DI,OFFSET FADDRE
        ADD     DI,AX

        MOV     AX,[DI+11]               ; ポインタのオーバーランチェック
        MOV     DX,[DI+13]
        MOV     CX,[DI+5]
        SUB     AX,CX
        MOV     CX,[DI+7]
        SBB     DX,CX
        MOV     CX,[PAKET_COUNT]        ; 読み取りサイズ
        TEST    DX,DX
        JNZ     BLO_J3
        CMP     CX,AX
        JC      BLO_J3
        MOV     CX,AX                   ; 読み取りサイズを修正
        MOV     [PAKET_COUNT],CX

BLO_J3: TEST    CX,CX
        JNZ     BLO_J4
        JMP     BLO_Q3
BLO_J4:
        MOV     AX,[DI+9];現在のクラスタ位置
        CALL    LC_FATCCSD
        MOV     DX,[DI+5];ポインタ位置下位
        AND     DX,7E00H
        OR      AX,DX

        MOV     BLO_BL,AX
        MOV     BLO_BH,BX
        MOV     SI,[DI+5]               ; ポインタの下位を取得
        AND     SI,01FFH                ; ポインタの端数を抽出
        MOV     CX,[PAKET_COUNT]        ; 読み取りサイズ
        LES     BX,DWORD PTR CS:[PAKET_DTA]; 格納先アドレス取得

BLO_Q_LP1:
        PUSH    BX
        PUSH    DI
        MOV     AX,BLO_BL
        MOV     BX,BLO_BH
        MOV     DI,OFFSET DTAREA
        CALL    SD_READ;ワークエリアに読み込み開始位置からデータをリード
        POP     DI
        POP     BX
        
BLO_Q_LP0:
        MOV     AL,[SI+DTAREA]
        MOV     ES:[BX],AL                 ; 取得データを転送
        INC     BX
        INC     SI
        TEST    SI,01FFH;セクタ越えチェック
        JZ      BLO_Q4
        DEC     CX;読み出しバイト数
        JNZ     BLO_Q_LP0
        JMP     BLO_Q3;読み出し終了か

BLO_Q4: 
        XOR     SI,SI;セクタカウントリセット

        MOV     AX,BLO_BL
        ADD     AX,0200H
        MOV     BLO_BL,AX
        MOV     AX,BLO_BH
        ADC     AX,0000H
        MOV     BLO_BH,AX
        MOV     AX,BLO_BL

        TEST    AX,7FFFH;クラスタ越えチェック
        JNZ     BLO_Q5
        PUSH    BX
        MOV     BX,BLO_BH
        SUB     AX,0200H
        SBB     BX,0000H
        PUSH    CX
        CALL    LC_FATUPD;FAT検索
        MOV     [DI+9],CX;現在のクラスタ位置を更新
        POP     CX
        MOV     BLO_BL,AX
        MOV     BLO_BH,BX
        POP     BX
        JMP     BLO_Q_LP1

BLO_Q5: 
        DEC     CX;読み出しバイト数
        JNZ     BLO_Q_LP1

BLO_Q3: LES	BX,DWORD PTR [PAKET_FCB]
	MOV	AX,[PAKET_COUNT]

	ADD	ES:[BX][POINT],AX       ; ポインタ更新
	ADC	ES:[BX][POINT][2],WORD PTR 0
        ADD     [DI+5],AX
        ADC     [DI+7],WORD PTR 0
	CALL	P_SAVE			; FILE POINTER SAVE

	JMP	EXIT

BLO_BL  DW      1 DUP(?)               ; ワークエリア
BLO_BH  DW      1 DUP(?)               ; 

;===== DATA OUTPUT =====

BLOCK_OUT:
        LES     BX,DWORD PTR [PAKET_FCB]
        MOV     AL,ES:[BX][S_HANDL]
        CALL    C_FHAND                 ; ハンドルチェック
        JC      BLO_OS_JP0
        MOV     AL,6                    ;Invalid handle
        JMP     ERR_EXIT
BLO_OS_JP0:
        CALL    P_MOVE                  ; 入力されてきたポインタまで移動

        MOV     AL,ES:[BX][S_HANDL]     ; ハンドル取得
        MOV     AH,HNDANM
        MUL     AH
        MOV     DI,OFFSET FADDRE
        ADD     DI,AX

        ;書き込めるか容量チェック
        MOV     CX,[PAKET_COUNT];書き込みバイト数取得
        MOV     AX,[DI+5];ポインタ位置下位
        MOV     BX,[DI+7];ポインタ位置上位
        ADD     AX,CX
        ADC     BX,0000H
        MOV     CX,[DI+11];ファイルサイズ下位
        MOV     DX,[DI+13];ファイルサイズ上位
        SUB     AX,CX
        SBB     BX,DX
        JB      BLO_OSJ0; A<B
        ; ファイルサイズを超えて書き込もうとしている場合
        SHL     CX,1
        RCL     DX,1
        INC     DX;現在使っているクラスタ数を生成
        MOV     CX,[PAKET_COUNT];書き込みバイト数取得
        MOV     AX,[DI+5];ポインタ位置下位
        MOV     BX,[DI+7];ポインタ位置上位
        ADD     AX,CX
        ADC     BX,0000H
        MOV     [DI+11],AX;ファイルサイズ更新
        MOV     [DI+13],BX;ファイルサイズ更新
        SHL     AX,1
        RCL     BX,1
        INC     BX;総必要クラスタ数を生成
        SUB     BX,DX;足りないクラスタ数生成
        CALL    D_SPC_S;空き容量(クラスタ)取得
        CMP     SI,BX
        JA      BOO_J1
        ;容量不足
        MOV     AL,5                    ;Disk full
        JMP     ERR_EXIT
BOO_J1: ;不足クラスタをFAT領域に登録
;        MOV     CX,[PAKET_COUNT];書き込みバイト数取得
;        MOV     AX,[DI+5];ポインタ位置下位
;        MOV     DX,[DI+7];ポインタ位置上位
;        ADD     AX,CX
;        ADC     DX,0000H
;        MOV     [DI+11],AX;ファイルサイズ更新
;        MOV     [DI+13],DX;ファイルサイズ更新

        ;クラスタが割り当てられていない場合の処理
        MOV     AX,[DI+2];FAT上で最初のクラスタ位置
        TEST    AX,AX;クラスタ番号が割り当てられていない場合
        JNZ     BOO_J6
        MOV     AX,FATFEN
        MOV     [DI+2],AX;最初のクラスタ更新
        MOV     [DI],AX;最後のクラスタ更新
        MOV     [DI+9],AX;現在のクラスタ位置更新

        XOR     AX,AX;0000Hを指定
        CALL    LC_FATMCN;FAT更新
        MOV     AX,FATUSEN
        DEC     AX
        MOV     FATUSEN,AX;空いてるクラスタ数を更新

BOO_J6:
        MOV     CX,BX
        TEST    CX,CX
        JZ      BLO_OSJ0;FAT追加が無い場合は飛ばす
;        MOV     AX,FATUSEN
;        DEC     AX
;        MOV     FATUSEN,AX;空いてるクラスタ数を更新
        MOV     AX,[DI];最終クラスタを取得
BOO_L0: CALL    LC_FATMCN
        MOV     DX,FATUSEN
        DEC     DX
        MOV     FATUSEN,DX;空いてるクラスタ数を更新
        LOOP    BOO_L0
        MOV     [DI],AX;最終クラスタ更新

BLO_OSJ0:
        ;ファイルデータ書き込み
        MOV     CX,[PAKET_COUNT];書き込みバイト数取得

        MOV     AX,[DI+9];現在のクラスタ位置
        CALL    LC_FATCCSD
        MOV     DX,[DI+5];ポインタ位置下位
        AND     DX,7E00H
        OR      AX,DX
        MOV     BLOSAX,AX;今のセクタ位置保存（下位）
        MOV     BLOSBX,BX;今のセクタ位置保存（上位）
        MOV     SI,DI;ハンドル情報をSIに変更
;        MOV     DI,OFFSET DTAREA
        LES     DX,DWORD PTR [PAKET_DTA]
        MOV     BLOSDT,DX;書き込みデータの位置を保存
        MOV     DX,[SI+5];ポインタ位置下位

BOO_L3:
        MOV     DI,OFFSET DTAREA
        CALL    SD_READ
BOO_L2:
        MOV     BX,BLOSDT
        MOV     AL,ES:[BX]
        INC     BX
        MOV     BLOSDT,BX
        MOV     BX,DX
        AND     BX,01FFH
        MOV     [DTAREA+BX],AL
        INC     DX

        TEST    DX,01FFH;512バイト分を超えたか
        JNZ     BOO_J2
        MOV     AX,BLOSAX
        MOV     BX,BLOSBX
        MOV     DI,OFFSET DTAREA
        CALL    SD_WRITE;データ書き込み
        TEST    DX,7FFFH;クラスタ分を超えたか
        JNZ     BOO_J3
        ;次のクラスタを検索する
        MOV     AX,BLOSAX
        MOV     BX,BLOSBX
        SUB     AX,0200H
        SBB     BX,0
        PUSH    CX
        CALL    LC_FATUPD
        MOV     [SI+9],CX;現在のクラスタ位置を更新
        POP     CX
        XOR     DX,DX;クラスタ内カウンタ初期化
        MOV     BLOSAX,AX
        MOV     BLOSBX,BX
        CMP     AX,0FFFFH;最終クラスタだった場合
        JNZ     BOO_J5
        MOV     AL,6                    ;Invalid handle
        JMP     ERR_EXIT

BOO_J3: ADD     AX,0200H
        ADC     BX,0000H
        MOV     BLOSAX,AX;今のセクタ位置保存（下位）
        MOV     BLOSBX,BX;今のセクタ位置保存（上位）
BOO_J5: LOOP    BOO_L3
        JMP     BOO_J4

BOO_J2: 
        LOOP    BOO_L2
        MOV     AX,BLOSAX
        MOV     BX,BLOSBX
        MOV     DI,OFFSET DTAREA
        CALL    SD_WRITE;データ書き込み
BOO_J4: 
	LES	BX,DWORD PTR [PAKET_FCB]
        MOV     DX,[PAKET_COUNT];書き込みバイト数取得
	ADD	ES:[BX][POINT],DX		;POINTER LOW
	ADC	ES:[BX][POINT][2],WORD PTR 0	;POINTER HI
        ADD     [SI+5],DX;ポインタ位置下位
        ADC     [SI+7],WORD PTR 0;ポインタ位置上位

	CALL	P_SAVE			;FILE POINTER SAVE

        ; SD内のEDA更新（ファイルサイズ更新）
        MOV     AX,[SI+16]
        AND     AX,0FE00H
        MOV     BX,[SI+18]
        MOV     DI,OFFSET DTAREA
        CALL    SD_READ;EDAロード
        MOV     CX,[SI+16]
        AND     CX,01FFH
        ADD     DI,CX
        MOV     DX,[SI+11];ファイルサイズ下位
        MOV     [DI+28],DX
        MOV     DX,[SI+13];ファイルサイズ上位
        MOV     [DI+30],DX
        MOV     DX,[SI+2];最初のクラスタ
        MOV     [DI+26],DX

        MOV     DI,OFFSET DTAREA
        CALL    SD_WRITE;SD内のEDA更新

	JMP	EXIT

BLOSAX  DW      1 DUP(?)
BLOSBX  DW      1 DUP(?)
BLOSDT  DW      1 DUP(?)

;===== FILE OPEN =====

OPEN:
        CALL    PATH_SET                ; パス設定
        JNC     LC_OJ6
        MOV     AX,0003H
        JMP     OPE_ER1

LC_OJ6: LES     BX,DWORD PTR [PAKET_FCB]

        CALL    G_FHAND                 ; 空きハンドル取得
        JNC     LC_OJ3
        MOV     AL,6
        JMP     ERR_EXIT
LC_OJ3: MOV     ES:[BX][S_HANDL],AL
        XOR     AX,AX
        MOV     ES:[BX][S_POINT],AX
        MOV     ES:[BX][S_POINT][2],AX  ; FILE POINTER CLEAR
        TEST    BYTE PTR ES:[BX],01H    ; mode check(現状読み込みのみサポート)
        JZ      LC_OJ4
        MOV     AL,01H                  ; Invalid function code
        JMP     ERR_EXIT
;------ 検索ファイル名準備 -------------
LC_OJ4: PUSH    DS
        PUSH    ES
        MOV     DI,OFFSET CHNAME        ; 検索ファイル名準備
        MOV     AX,DS
        MOV     ES,AX
        MOV     CX,11
        LDS     SI,DWORD PTR CS:[PAKET_FCB]
        INC     SI
        REP     MOVSB
        POP     ES
        POP     DS
;------ ファイル情報取得 ---------------
        XOR     AL,AL
        JMP     LC_OJ1
LC_OL1: MOV     AL,01H
LC_OJ1: CALL    LC_SRCEDR               ; ED検索
        CMP     SI,0FFFFH
        JNZ     LC_OJ0
        LES     BX,DWORD PTR [PAKET_FCB]
        MOV     AL,ES:[BX][S_HANDL]
        CALL    R_FHAND
        MOV     AX,2                    ; File not found
        JMP     ERR_EXIT                ; file無し終了
LC_OJ0: MOV     CL,[SI+11]              ; 属性チェック
        NOT     CL
        TEST    CL,0FH
        JZ      LC_OL1                  ; ロングファイルネームだったら検索失敗
        MOV     CX,11
        MOV     AX,DS
        MOV     ES,AX
        MOV     DI,OFFSET CHNAME
LC_OL0: CMPSB
        JNZ     LC_OL1                  ; 検索失敗
        LOOP    LC_OL0
        LES     BX,DWORD PTR [PAKET_FCB]
        MOV     AL,ES:[BX][S_HANDL]
        MOV     CL,AL
        MOV     DI,OFFSET FADDRE
        MOV     AH,HNDANM
        MUL     AH
        ADD     DI,AX
        MOV     AX,[SI+15]
        MOV     [DI+2],AX               ; FAT上で最初のクラスタ位置(下位)
        MOV     [DI+9],AX               ; 現在のクラスタ位置格納
        XOR     AX,AX
        MOV     [DI+4],AL               ; セクタ位置初期化
        MOV     [DI+5],AX               ; ポインタ初期化1
        MOV     [DI+7],AX               ; ポインタ初期化2
        MOV     AX,[SI+17]
        MOV     [DI+11],AX              ; ファイルサイズ格納(下位)
        MOV     AX,[SI+19]
        MOV     [DI+13],AX              ; ファイルサイズ格納(上位)

        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        MOV     CX,EDSRCO
        ADD     AX,CX
        SUB     AX,0020H
        SBB     BX,0000H
        MOV     [DI+16],AX              ; オープンファイルのEDAアドレス（下位）
        MOV     [DI+18],BX              ; オープンファイルのEDAアドレス（上位）

        ;最終クラスタ検出
        MOV     AX,[DI+2];スタートクラスタ
LC_OJ7: MOV     BX,AX
        CALL    LC_FATSFC
        CMP     AX,0FFFFH
        JNZ     LC_OJ7
        MOV     [DI],BX                 ; 最終クラスタ番号格納

        JMP     EXIT
OPE_ER1:
        JMP     ERR_EXIT


;===== FILE CLOSE =====
CLOSE:
        LES     BX,DWORD PTR [PAKET_FCB]
        MOV     AL,ES:[BX][S_HANDL]
        CALL    C_FHAND                 ; ハンドルチェック
        JNC     CLO_ER1
        CALL    R_FHAND                 ; ハンドルリセット
        MOV     DI,OFFSET FADDRE
        MOV     AH,HNDANM
        MUL     AH
        ADD     DI,AX
        XOR     AX,AX
        MOV     [DI],AX                 ; 最終クラスタ位置初期化
        MOV     [DI+2],AX               ; クラスタ位置初期化
        MOV     [DI+9],AX
        MOV     [DI+4],AL               ; セクタ位置初期化
        MOV     [DI+5],AX               ; ポインタ初期化1
        MOV     [DI+7],AX               ; ポインタ初期化2
        MOV     [DI+11],AX              ; ファイルサイズ初期化(下位)
        MOV     [DI+13],AX              ; ファイルサイズ初期化(上位)
        MOV     [DI+16],AX              ; EDAセクタ(下位)
        MOV     [DI+18],AX              ; EDAセクタ(上位)

        JMP     EXIT

CLO_ER1:
        MOV     AL,6                    ;Invalid handle
CLO_ER2:
        JMP     ERR_EXIT


;-----------------------------
;===== DRIVE DEVICE ONLY =====

;===== FILE CREATE =====

CREATE:
        CALL    PATH_SET                ; パス設定
        JNC     LC_CJ1
        MOV     AX,0003H
        JMP     ERR_EXIT
LC_CJ1:
;	CALL	G_FHAND
;	LES	BX,DWORD PTR [PAKET_FCB]
;	MOV	ES:[BX][S_HANDL],AL
;ファイルハンドルも作る？

        XOR     AX,AX
        MOV     EDSRCO,AX
        MOV     AX,SDCLUS               ; サブディレクトリかチェック
        TEST    AX,AX
        JZ      LC_CJ2
        ;サブディレクトリの場合
        MOV     CX,SDESECL              ;現在のSubDirの先頭セクタ番号（下位）
        MOV     EDADDR,CX               
        MOV     CX,SDESECW              ;現在のSubDirの先頭セクタ番号（上位）
        MOV     EDADDRH,CX
        JMP     LC_CJ3
LC_CJ2: ;ルートの場合
        MOV     CX,RDESECL              ; ルートの場合
        MOV     EDADDR,CX               ;RuteDirEntryの先頭セクタ番号（下位）
        MOV     CX,RDESECW
        MOV     EDADDRH,CX              ;RuteDirEntryの先頭セクタ番号（上位）
LC_CJ3: 
        MOV     DI,OFFSET DTAREA
        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        CALL    SD_READ                 ; data read 
        ;読み取りエラー処理省略
        XOR     BX,BX                   ; セクタ内ポインタ初期化

        ;Entryチェック
LC_CJ5: MOV     SI,OFFSET DTAREA
        ADD     SI,BX
        MOV     AL,[SI]
        TEST    AL,AL                   ; 終端(00H)(空き)チェック
        JZ      LC_CJ4
        CMP     AL,0E5H                 ; 削除ファイル(空き)チェック
        JZ      LC_CJ4                  ; 
        ADD     BX,0020H                ; 次のNoのチェックへ
        CMP     BX,0200H;512バイト分
        JB      LC_CJ5;(BX<0200H)

        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        ADD     AX,0200H
        ADC     BX,0000H
        MOV     EDADDR,AX
        MOV     EDADDRH,BX
        TEST    AX,7FFFH                ; クラスタ超過チェック
        JNZ     LC_CJ3
        ; クラスタを超えたためFATチェック
        SUB     AX,0200H
        SBB     BX,0000H
        CALL    LC_FATUPD
        MOV     EDADDR,AX
        MOV     EDADDRH,BX
        CMP     BX,0FFFFH
        JNZ     LC_CJ3
        CMP     AX,0FFFFH
        JNZ     LC_CJ3
        MOV     AX,0003H
        JMP     ERR_EXIT               ; 空き無しのため終了

LC_CJ4: MOV     DI,OFFSET DTAREA
        ADD     DI,BX
        PUSH    ES
        MOV     AX,DS
        MOV     ES,AX
        ; ファイルエントリを作成
	PUSH	DS
	LDS	SI,DWORD PTR CS:[PAKET_FCB]
	INC	SI			;DRIVE No. PASS
	MOV	CX,11
        REP     MOVSB;ファイル名作成
	POP	DS
        MOV     AL,20H
        STOSB;属性作成
        MOV     AL,08H
        STOSB;NTフラグ
        XOR     AL,AL
        STOSB;1/200秒

        MOV     AH,2CH;時刻取得
        INT     21H
        MOV     AX,CX
        SHR     DH,1;秒生成
        XOR     CH,CH
        SAL     CX,1
        SAL     CX,1
        SAL     CX,1
        SAL     CX,1
        SAL     CX,1;分生成
        SAL     AH,1
        SAL     AH,1
        SAL     AH,1;時生成
        XOR     AL,AL
        OR      AX,CX
        OR      AL,DH;時間生成
        STOSW;crtTime（作成時間）

        MOV     AH,2AH;日付取得
        INT     21H
        MOV     AX,1980
        SUB     CX,AX
        MOV     AH,CL
        MOV     CL,4
        SAL     DH,CL;月
        RCL     AH,1;年生成
        MOV     AL,DH
        OR      AL,DL;
        STOSW;crtDate（作成日）
        STOSW;lstAccDate（ラストアクセス日）
        XOR     AX,AX
        STOSW;fstClusHI（開始クラスタ上位）
        MOV     AX,[DI-8]
        STOSW;wrtTime（ラスト書き込み時刻）
        MOV     AX,[DI-8]
        STOSW;wrtDate（ラスト書き込み日付）
        XOR     AX,AX
        STOSW;fstClusLO（開始クラスタ下位）
        STOSW;fileSize（ファイルサイズ）
        STOSW;fileSize（ファイルサイズ）

        POP     ES

        MOV     DI,OFFSET DTAREA
        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        CALL    SD_WRITE;書き込み

        XOR     AX,AX

        JMP     EXIT


;===== FILE DELETE =====

DELETE:

;        CALL    PATH_SET                ; パス設定  （エラーになる。うまくいかないので一旦保留）
;        JNC     LC_ET1
;        MOV     AX,0003H
;        JMP     ERR_EXIT

LC_ET1:
; ファイル名検索

        CALL    SS_GETEDR
        CMP     AX,2
        JNZ     LC_ET2
        JMP     ERR_EXIT                ; file無し終了
LC_ET2: 
        ; SFN構造体更新処理
        MOV     AL,[SI+11]
        TEST    AL,01H;書き込み禁止かチェック
        JZ      LC_ET3
        JMP     ERR_EXIT
LC_ET3: MOV     AL,0E5H;空きコード(削除コード)
        MOV     [SI],AL
        MOV     AX,[SI+26]
        MOV     DSRCCL,AX;削除クラスタNOを保存
        
LC_EJ6: SUB     SI,0020H;ロングファイル名チェック
        CMP     SI,OFFSET DTAREA
        JAE     LC_ET4;A >= B
;一個前のセクタをロード
        MOV     DI,OFFSET DTAREA
        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        CALL    SD_WRITE;今までの状態を書き込み
        SUB     AX,0200H
        SBB     BX,0000H
        MOV     EDADDR,AX
        MOV     EDADDRH,BX
        CALL    SD_READ;一個前のセクタ読み込み
        MOV     SI,OFFSET DTAREA
        ADD     SI,01E0H

LC_ET4: MOV     AL,[SI]
        CMP     AL,0E5H;削除コードチェック
        JZ      LC_EJ5
        MOV     AL,[SI+11]
        CMP     AL,0FH;LFNかチェック
        JNZ     LC_EJ5
        ; LFNである。
        MOV     AL,0E5H;空きコード(削除コード)
        MOV     [SI],AL
        JMP     LC_EJ6
LC_EJ5: 
        ;LFNではない。終了
        MOV     DI,OFFSET DTAREA
        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        CALL    SD_WRITE;書き込み

        ; FAT更新処理
LC_ET7: MOV     AX,DSRCCL;削除FAT番号
        TEST    AX,AX;FAT番号が0000Hだったら終了
        JZ      LC_ET9
        MOV     DX,FATUSEN
        INC     DX
        MOV     FATUSEN,DX;使用クラスタ数を更新
        MOV     DX,FATFEN
        CMP     AX,DX
        JAE     LC_ET8;AX >= DX
        MOV     FATFEN,AX;一番若いFAT番号を更新
LC_ET8: MOV     DX,2
        MUL     DX
        MOV     BX,512
        DIV     BX

        MOV     DSRSDX,DX;セクタ中の更新FAT番号位置を保持
        MUL     BX
        XCHG    BX,DX
        PUSH    AX
        PUSH    BX
        MOV     CX,FATTSCL                ; FAT1のセクタ番号を保存（下位）
        MOV     DX,FATTSCW                ; FAT1のセクタ番号を保存（上位）
        ADD     AX,CX
        ADC     BX,DX
        MOV     DI,OFFSET DTAREA
        CALL    SD_READ;FAT読み込み
        MOV     DX,DSRSDX
        ADD     DI,DX
        MOV     CX,[DI];次の削除クラスタNOを保存
        MOV     DSRCCL,CX
        MOV     WORD PTR [DI],0000H;FAT削除書き込み
        MOV     DI,OFFSET DTAREA
        CALL    SD_WRITE;SD内FAT1書き込み
        POP     BX
        POP     AX
        MOV     CX,FAT2SCL                ; FAT2のセクタ番号を保存（下位）
        MOV     DX,FAT2SCW                ; FAT2のセクタ番号を保存（上位）
        ADD     AX,CX
        ADC     BX,DX
        CALL    SD_WRITE;SD内FAT2書き込み
        MOV     CX,DSRCCL
        CMP     CX,0FFFFH
        JNZ     LC_ET7
LC_ET9:
        JMP     EXIT

DSRCCL  DW      1 DUP(?)
DSRSDX  DW      1 DUP(?)

;===== FILE RENAME =====

RENAME:
        CALL    PATH_SET                ; パス設定
        JNC     LC_RJ1
        MOV     AX,0003H
        JMP     ERR_EXIT

LC_RJ1: 
; 新しいファイル名の重複チェック
        CALL    SS_GETEDR2
        CMP     AX,0002H
        JZ      LC_RJ3;ファイルがなかったら重複なし
        MOV     AX,0002H
        JMP     ERR_EXIT;ファイルが重複している
LC_RJ3:
; ファイル名更新
        CALL    SS_GETEDR
        CMP     AX,2
        JNZ     LC_RJ2
        JMP     ERR_EXIT                ; file無し終了
LC_RJ2: 
        LES	DI,DWORD PTR [PAKET_DTA]
        MOV	CX,11
LC_LPLP1:
        MOV     AL,ES:[DI]
        MOV     [SI],AL;保存中のEDR内のファイル名を更新
        INC     DI
        INC     SI
        LOOP    LC_LPLP1
;        REP     MOVSB;保存中のEDR内のファイル名を更新
        
        MOV     DI,OFFSET DTAREA
        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        CALL    SD_WRITE;書き込み

        JMP     EXIT


;------------------------------
;Name : SS_GETEDR (ファイル名からEDR情報を取得する為のサブルーチン)
;Input : none
;Output : SI -> EDR情報格納アドレス
;         AX -> エラーコード（2:該当ファイル無）
;Description : 

SS_GETEDR:
        PUSH    CX
        PUSH    DS
        PUSH    ES
        MOV     DI,OFFSET CHNAME        ; 検索ファイル名準備
        MOV     AX,DS
        MOV     ES,AX
        MOV     CX,11
        LDS     SI,DWORD PTR [PAKET_FCB]
        INC     SI
        REP     MOVSB
        POP     ES
        POP     DS
        POP     CX
;------ ファイル情報取得 ---------------
SS_GLS:
        XOR     AL,AL
        JMP     SS_GJ1
SS_GL1: MOV     AL,01H
SS_GJ1: CALL    LC_SRCEDR               ; ED検索
        CMP     SI,0FFFFH
        JNZ     SS_GJ0
        MOV     AX,2                    ; File not found
        JMP     SS_RET                  ; file無し終了
SS_GJ0: MOV     CL,[SI+11]              ; 属性チェック
        NOT     CL
        TEST    CL,0FH
        JZ      SS_GL1                  ; ロングファイルネームだったら検索失敗
        MOV     CX,11
        MOV     AX,DS
        MOV     ES,AX
        MOV     DI,OFFSET CHNAME
SS_GL0: CMPSB
        JNZ     SS_GL1                  ; 検索失敗
        LOOP    SS_GL0

        SUB     SI,000BH
        XOR     AX,AX

SS_RET: 
        RET

;------ 更新ファイル名の重複チェック用 ---------------
SS_GETEDR2:
        PUSH    CX
        PUSH    DS
        PUSH    ES
        MOV     DI,OFFSET CHNAME        ; 検索ファイル名準備
        MOV     AX,DS
        MOV     ES,AX
        MOV     CX,11
        LDS     SI,DWORD PTR [PAKET_DTA];更新ファイル名
        INC     SI
        REP     MOVSB
        POP     ES
        POP     DS
        POP     CX

        JMP     SS_GLS

;===== DIRECTORY SEARCH =====

SEARCH:
        CALL    PATH_SET                ; パス設定
        JNC     LC_BJ6
        MOV     AX,0003H
        JMP     SEA_ER

;----- カード初期化チェック ------------
LC_BJ6: CALL    LC_INITCK               ; 初期化情報チェック
        JC      LC_BJ7
        JMP     SEA_J5
LC_BJ7: MOV     AL,21                   ; drive is not ready
        JMP     ERR_EXIT

SEA_J5:	LES	DI,DWORD PTR [PAKET_DTA]
	MOV	DX,ES:[DI]              ;
	AND	DX,DX
	JNZ	SEA_JP0_1
	LES	DI,DWORD PTR [PAKET_FCB]
	MOV	ES:[DI][DIR_NO],DX      ; DIRECTORY No. RESET
SEA_JP0_1:
        XOR     AL,AL
        LES     DI,DWORD PTR [PAKET_FCB]
        MOV     DX,ES:[DI][DIR_NO]      ; DIRECTORY No.
        TEST    DX,DX
        JZ      SEA_J1
        MOV     AL,01H                  ; 続きから検索
SEA_J1: LES     DI,DWORD PTR CS:[PAKET_FCB]
        CMP     ES:[DI+1],BYTE PTR 3FH  ; FileNameにデータが入っているかチェック
        JZ      SEA_J3

        XOR     AL,AL                   ; FileNameが入っていた場合
        MOV     BX,DX                   ; DIRECTORY No分読みとばす為のカウンタ
        XOR     DX,DX
        INC     BX
        JMP     SE_GJ1
SE_GL1: MOV     AL,01H
        INC     DX
SE_GJ1: PUSH    DX
        CALL    LC_SRCEDR               ; ED検索
        POP     DX
        CMP     SI,0FFFFH
        JNZ     SE_GJ0
        MOV     AX,2                    ; File not found
        JMP     ERR_EXIT                ; file無し終了
SE_GJ0: CMP     DX,BX                   ; DIRECTORY No分読みとばす
        JNC     SEA_J4
        JMP     SE_GL1
SEA_J4: MOV     CX,11
        LES     DI,DWORD PTR CS:[PAKET_FCB]
        INC     DI
SE_GL0: CMPSB
        JNZ     SE_GL1                  ; 検索失敗
        LOOP    SE_GL0
        SUB     SI,11
        JMP     SEA_J2

SEA_J3: PUSH    DX
        CALL    LC_SRCEDR               ; ED検索
        POP     DX
        CMP     SI,0FFFFH
        JNZ     SEA_J2

        MOV     AL,2                    ; ?File not found
        TEST    DX,DX
        JZ      SEA_ER
        MOV     AL,18                   ; No more files
SEA_ER: JMP     ERR_EXIT

SEA_J2: INC     DX
        LES     DI,DWORD PTR [PAKET_FCB]
        MOV     ES:[DI][DIR_NO],DX      ; DIRECTORY No.
        LES     DI,DWORD PTR [PAKET_DTA]
        MOV     CX,12
        REP     MOVSB                   ; file name & 属性 格納
        XOR     AX,AX
        MOV     CX,10
        REP     STOSB
        ADD     SI,10
        MOV     CX,4
        REP     MOVSB                   ; 時間と日付を格納
        XOR     AX,AX
        STOSW
        ADD     SI,2
        MOV     CX,4
        REP     MOVSB                   ; ファイルサイズ格納

        MOV     [PAKET_STATUS],01000000B
        MOV     [PAKET_COUNT],32
        JMP     EXIT

;===== FILE STATUS GET =====

STATUS_GET:
        CALL    PATH_SET                ; パス設定
        JNC     LC_BJ5
        MOV     AX,0003H
        JMP     ERR_EXIT

;----- カード初期化チェック ------------
LC_BJ5: CALL    LC_INITCK               ; 初期化情報チェック
        JC      LC_BJ4
        JMP     LC_BJ0
LC_BJ4: MOV     AL,21                   ; drive is not ready
        JMP     ERR_EXIT
;------ ファイル名格納処理 -------------
LC_BJ0: 
        PUSH    CX
        PUSH    DS
        PUSH    ES
        MOV     DI,OFFSET CHNAME        ; 検索ファイル名準備
        MOV     AX,DS
        MOV     ES,AX
        MOV     CX,11
        LDS     SI,DWORD PTR [PAKET_FCB]
        INC     SI
        REP     MOVSB
        POP     ES
        POP     DS
        POP     CX
;------ ファイル情報取得 ---------------
        XOR     AL,AL
        JMP     LC_GJ1
LC_GL1: MOV     AL,01H
LC_GJ1: CALL    LC_SRCEDR               ; ED検索
        CMP     SI,0FFFFH
        JNZ     LC_GJ0
        MOV     AX,2                    ; File not found
        JMP     ERR_EXIT                ; file無し終了
LC_GJ0: MOV     CL,[SI+11]              ; 属性チェック
        NOT     CL
        TEST    CL,0FH
        JZ      LC_GL1                  ; ロングファイルネームだったら検索失敗
        MOV     CX,11
        MOV     AX,DS
        MOV     ES,AX
        MOV     DI,OFFSET CHNAME
LC_GL0: CMPSB
        JNZ     LC_GL1                  ; 検索失敗
        LOOP    LC_GL0

        LES     DI,DWORD PTR [PAKET_DTA]
        MOV     AX,[SI+0BH]             ; TIME
        STOSW
        MOV     AX,[SI+0DH]             ; DATE
        STOSW
        MOV     AL,[SI+00H]             ; ATTR
        STOSB
        MOV     AX,[SI+11H]             ; SIZEL
        STOSW
        MOV     AX,[SI+13H]             ; SIZEH
        STOSW

        JMP     EXIT

;===== DATE & TIME SET =====

DATETIME:
        CALL    PATH_SET                ; パス設定
        JNC     LC_DJ1
        MOV     AX,0003H
        JMP     ERR_EXIT
LC_DJ1:
; ファイル名検索
        CALL    SS_GETEDR
        CMP     AX,2
        JNZ     LC_DJ2
        JMP     ERR_EXIT                ; file無し終了
LC_DJ2: 
        LES     BX,DWORD PTR [PAKET_DTA]
        MOV     AX,ES:[BX]
        MOV     [SI+22],AX
        MOV     AX,ES:[BX+2]
        MOV     [SI+24],AX

        MOV     DI,OFFSET DTAREA
        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        CALL    SD_WRITE;書き込み

        JMP     EXIT

;===== ATTRIBUTES SET =====

ATTRIB_SET:

        CALL    PATH_SET                ; パス設定
        JNC     LC_AJ1
        MOV     AX,0003H
        JMP     ERR_EXIT
LC_AJ1:
; ファイル名検索
        CALL    SS_GETEDR
        CMP     AX,2
        JNZ     LC_AJ2
        JMP     ERR_EXIT                ; file無し終了
LC_AJ2: 
        LES     BX,DWORD PTR [PAKET_DTA]
        MOV     AL,ES:[BX]
        MOV     [SI+11],AL; 属性更新

        MOV     DI,OFFSET DTAREA
        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        CALL    SD_WRITE;書き込み

        JMP     EXIT

;===== DRIVE ONLINE CHECK =====

ONLINE:
	CALL	DRIVE_GET
	XOR	AH,AH
	CMP	AL,3
	JZ	ONL_JP1
	MOV	AH,10000000B		;b7=ONLINE FLAG
ONL_JP1:
	MOV	BYTE PTR [PAKET_STATUS],AH
	JMP	EXIT2

;===== DISK SPACE GET =====

D_SPACE:

;----- カード初期化チェック ------------ 
        CALL    LC_INITCK               ; 初期化情報チェック
        JC      D_QP4
        JMP     D_QP5
D_QP4:  MOV     AL,21                   ; drive is not ready
        JMP     ERR_EXIT

D_QP5:
	LES	DI,DWORD PTR [PAKET_DTA]
	MOV	AL,SPCNUM
        XOR     AH,AH
	STOSW				;ｾｸﾀ/ｸﾗｽﾀ
	MOV	AX,512
	STOSW				;ﾊﾞｲﾄ/ｾｸﾀ

        CALL    D_SPC_S

        MOV     AX,SI
        STOSW                           ;ｸﾗｽﾀ ｻｲｽﾞ
        MOV     AX,WORD PTR DSWORK3
        STOSW                           ;ALL ｸﾗｽﾀ ｻｲｽﾞ

        JMP     EXIT

D_JP1:
	JMP     ERR_EXIT

;sub rutine 
;in → なし
;out → SI空きクラスタ数
D_SPC_S:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI

        MOV     SI,FATUSEN;計算済かチェック
        TEST    SI,SI
        JNZ     D_QP2

        MOV     AX,WORD PTR FSTSEC
        MOV     BL,40H
        DIV     BL
        XOR     AH,AH
        MOV     CX,AX
        MOV     AX,WORD PTR RDESECL
        MOV     DX,WORD PTR RDESECW
        MOV     BX,8000H
        DIV     BX
        MOV     BX,AX
        MOV     AX,WORD PTR FATANUM
        SUB     AX,BX
        ADD     AX,CX
        MOV     WORD PTR DSWORK3,AX

        MOV     CX,AX;全クラスタ数を取得
        XOR     SI,SI;空きクラスタカウント初期化

        MOV     AX,WORD PTR FATTSCL
        MOV     BX,WORD PTR FATTSCW
        MOV     WORD PTR DSWORK1,AX
        MOV     WORD PTR DSWORK2,BX
        XOR     AX,AX;クラスタ番号保持

D_QP3:
        PUSH    AX
        MOV     AX,WORD PTR DSWORK1
        MOV     BX,WORD PTR DSWORK2
        MOV     DI,OFFSET DTAREA
        CALL    SD_READ;ワークエリアに読み込み開始位置からデータをリード
        ADD     AX,0200H
        ADC     BX,0000H
        MOV     WORD PTR DSWORK1,AX
        MOV     WORD PTR DSWORK2,BX
        XOR     BX,BX
        POP     AX

D_QP1:
        MOV     DX,[DI+BX]
        TEST    DX,DX
        JNZ     D_QP0;
        INC     SI;空いてるクラスタをカウント
        MOV     DX,FATFEN
        CMP     AX,DX
        JAE     D_QP0;AX >= DX
        MOV     FATFEN,AX;一番若いFAT番号を更新
D_QP0:  INC     AX
        DEC     CX
        JZ      D_QP2
        ADD     BX,2
        CMP     BX,512
        JAE     D_QP3
        JMP     D_QP1
D_QP2:  
        MOV     FATUSEN,SI;使用クラスタ数保存
        ADD     SI,2;微調整

        POP     DI
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET

DSWORK1 DW      1 DUP(?)
DSWORK2 DW      1 DUP(?)
DSWORK3 DW      1 DUP(?)

;===== DRIVE FORMAT =====

FORMAT:
; ----- 現状未対応 ------
	MOV	AX,0001H		; Invalid Function Code
	JMP	ERR_EXIT

;===== SUB-DIRECTORY SEARCH =====

SD_SRCH:
;        CALL    LC_CHKPAT
;        JNC     SD_J00                  ; パスが同じ
;        CALL    LC_SRCSUB               ; パス検索
;        JC      SD_E00
;        CALL    LC_PATCOP               ; パスを更新
        CALL    PATH_SET
        JC      SD_E00

SD_J00:
        JMP     EXIT

SD_E00: MOV     AX,0003H
        JMP     ERR_EXIT

;----- GET DRIVE NUMBER -----

DRIVE_GET:
	PUSH	ES
	LES	BX,DWORD PTR [PAKET_FCB]
	MOV	AH,ES:[BX]		;DRIVE No.
	AND	AX,0000111100000000B
	CMP	[DRIVENO],AH		;?DRIVE NO
	JZ	DR_G_JP1
        MOV     AL,3
DR_G_JP1:
	POP	ES
	RET

;----- DEVICE CLOSE -----

DRV_CLOSE:
	MOV	SI,OFFSET PAKET
	MOV	CX,12
	REP MOVSB
	RET

;------------------------------------------------------------------------------
;###### Sub Routine ###########################################################

;------------------------------------------------------------------------------
;Name : LC_GETPBR (PBR情報取得処理)
;Input : none
;Output : DL -> error code
;Description : FATのPBR領域を検索し各情報をそれぞれのメモリエリアに書き込む
;              FAT情報も更新する
;------------------------------------------------------------------------------
LC_GETPBR:
;        PUSH    AX
;        PUSH    BX
;        PUSH    CX
;        PUSH    DI
;------ 
        ; MBR取得
        MOV     DI,OFFSET DTAREA
        XOR     AX,AX
        MOV     WORD PTR FSTSEC,AX
        XOR     BX,BX
        CALL    SD_READ                   ; 0セクタ目(MBR)を取得
        CMP     BYTE PTR [DI],0EBH        ; BPBかチェック
        JZ      LD_JGA
        CMP     BYTE PTR [DI],0E9H        ; BPBかチェック
        JZ      LD_JGA
        MOV     AX,WORD PTR [DI+454]      ; BPB先頭クラスタ
        MOV     WORD PTR FSTSEC,AX
        MOV     DX,0200H
        MUL     DX                        ; AX,DX:BPBのセクタ番号を格納

        MOV     BX,DX
        MOV     CX,AX
        ADD     AX,0200H
        ADC     DX,0000H
        MOV     FATTSCL,AX                ; FAT1のセクタ番号を保存（下位）
        MOV     FATTSCW,DX                ; FAT1のセクタ番号を保存（上位）

        MOV     AX,CX
        MOV     BX,DX
        MOV     DI,OFFSET DTAREA
        CALL    SD_READ                   ; 取得したBPBセクタ番号からBPBを取得
LD_JGA: 
        MOV     DI,OFFSET DTAREA

;        MOV     AX,[DI+14]                ; 先頭の予約セクタ数
;        MOV     DX,0200H
;        MUL     DX
;        MOV     BX,FATTSCL                ; FAT1のセクタ番号を保存（下位）
;        MOV     DX,FATTSCW                ; FAT1のセクタ番号を保存（上位）
;        ADD     AX,BX
;        ADC     DX,0000H
;        MOV     FATTSCL,AX                ; FAT1のセクタ番号を保存（下位）
;        MOV     FATTSCW,DX                ; FAT1のセクタ番号を保存（上位）

;------ BPB処理(各FATの情報を格納)-------
        MOV     AL,[DI+0DH]             ;
        MOV     SPCNUM,AL               ; 1クラスタのセクタ数
        MOV     AL,[DI+10H]             ;
        MOV     FATNUM,AL               ; FATの数(通常2)
        MOV     AX,[DI+11H]             ;
        MOV     WORD PTR RDENUM,AX      ; ルートディレクトリエントリ数
        MOV     AX,[DI+13H]             ;
        MOV     WORD PTR TSECTER,AX     ; ディスク領域の総セクタ数
        MOV     AX,[DI+16H]             ;
        MOV     WORD PTR NFATNUM,AX     ; FAT1個のセクタ数
        MOV     AX,[DI+20H]             ;
        MOV     WORD PTR HSECTE1,AX     ; ディスク領域の総セクタ数(下位)
        MOV     AX,[DI+22H]             ;
        MOV     WORD PTR HSECTE2,AX     ; ディスク領域の総セクタ数（上位）

        ; FAT16か判断
        MOV     AX,WORD PTR NFATNUM
        CMP     AX,0000H
        JNZ     LD_GP5
        JMP     LD_GP1                  ; FAT32のためエラー
LD_GP5: XOR     DX,DX
        MOV     AX,WORD PTR TSECTER
        CMP     AX,0000H
        JNZ     LD_GP2
        MOV     AX,WORD PTR HSECTE1
        MOV     DX,WORD PTR HSECTE2
LD_GP2: SUB     AX,35
        SBB     DX,0000H
        SUB     AX,WORD PTR NFATNUM
        SBB     DX,0000H
        MOV     CX,512
        DIV     CX
        CMP     AX,WORD PTR 4085
        JB      LD_GP3                  ; FAT12のためエラー

        MOV     AX,WORD PTR NFATNUM
        MOV     BX,0200H
        MUL     BX
        MOV     BX,FATTSCL
        MOV     CX,FATTSCW
        ADD     BX,AX
        ADC     CX,DX
        MOV     FAT2SCL,BX                ; FAT2のセクタ番号を保存（下位）
        MOV     FAT2SCW,CX                ; FAT2のセクタ番号を保存（下位）
        ADD     BX,AX
        ADC     CX,DX
        MOV     RDESECL,BX                ; RuteDirEntryのセクタNo保存（下位）
        MOV     RDESECW,CX                ; RuteDirEntryのセクタNo保存（上位）
        SHL     BX,1
        RCL     CX,1
        MOV     FATTCT,CX;ルートがあるクラスタの先頭クラスタ番号を生成

        ; SDカードの全クラスタ数（FAT数）を保存
        MOV     AX,WORD PTR HSECTE1              ; ディスク領域の総セクタ数
        MOV     DX,WORD PTR HSECTE2              ; ディスク領域の総セクタ数
        MOV     BL,SPCNUM                        ; 1クラスタのセクタ数
        XOR     BH,BH
        DIV     BX
        MOV     FATANUM,AX

        ; FAT情報更新
        MOV     DI,OFFSET FATDATA
        MOV     AX,FATTSCL
        MOV     BX,FATTSCW
        CALL    SD_READ                   ; FAT1の先頭１セクタ分を取得
        MOV     AH,00H
;        MOV     FATSEC,AH

        XOR     DL,DL
LC_JG1: 
;        POP     DI
;        POP     CX
;        POP     BX
;        POP     AX
        RET

        ; エラーメッセージ
LD_GP1: MOV	DX,OFFSET TITLE_MSG6
	MOV	AH,9
	INT	21H
        JMP     LD_GP4
LD_GP3: MOV	DX,OFFSET TITLE_MSG5
	MOV	AH,9
	INT	21H
LD_GP4: MOV     DL,0FFH
        JMP     LC_JG1

;------------------------------------------------------------------------------
;Name : LC_INITCK (初期化チェック)
;Input : 
;Output : CarryFlag -> error status(0 -> OK, FF -> NG)
;Description : カード情報及びFAT情報が取得されているかをチェック
;              NGの場合は情報を更新
;------------------------------------------------------------------------------
LC_INITCK:
        PUSH    AX
        PUSH    DX

        MOV     AL,SMFLAG               ; 初期化フラグチェック
        TEST    AL,01H
        JNZ     LC_IJ0

        CALL    SD_CINIT                ; SDカードの初期化プロセス
        TEST    DH,0FFH
        JNZ     LC_IJ1                  ; 初期化プロセスエラー
        CALL    SD_CINI2                ; SDカード初期設定２、カード容量計算
        TEST    DH,0FFH
        JNZ     LC_IJ1                  ; 初期化プロセスエラー

; LOG
        ; 初期化成功関係メッセージ出力
	MOV	DX,OFFSET TITLE_MSG3
	MOV	AH,9
	INT	21H                     ; 初期化成功メッセージ

        CALL    LC_GETPBR               ; PBR/FAT領域取得
        CMP     DL,00H
        JNZ     LC_IJ1

        MOV     AL,SMFLAG               ; フラグ更新
        OR      AL,01H
        MOV     SMFLAG,AL

LC_IJ0: CLC
        JMP     LC_IJ2
LC_IJ1: STC
	MOV	DX,OFFSET TITLE_MSG4
	MOV	AH,9
	INT	21H                     ; 初期化失敗メッセージ
LC_IJ2:
        POP     DX
        POP     AX
        RET

;------------------------------------------------------------------------------
;Name : LC_SRCEDR (ディレクトリエントリ検索処理)
;Input : AL = 00H->先頭から検索 00H以外->続きから検索
;Output : DL -> error code
;       : SI -> 検索したED情報の先頭アドレス。情報がない場合はFFFFH
;Description : 
;------------------------------------------------------------------------------
LC_SRCEDR:

        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI

        TEST    AL,AL                   ; 先頭から検索か
        JZ      LC_EJ0
        ;続きから検索
        MOV     BX,EDSRCO               ; 現在のポインタをロード
        JMP     LC_EJ4

LC_EJ0: ;先頭から検索
        XOR     AX,AX
        MOV     EDSRCO,AX
        MOV     AX,SDCLUS               ; サブディレクトリかチェック
        TEST    AX,AX
        JZ      LC_EJB
        ;サブディレクトリの場合
        MOV     CX,SDESECL              ;現在のSubDirの先頭セクタ番号（下位）
        MOV     EDADDR,CX               
        MOV     CX,SDESECW              ;現在のSubDirの先頭セクタ番号（上位）
        MOV     EDADDRH,CX
        JMP     LC_ELD
LC_EJB: ;ルートの場合
        MOV     CX,RDESECL              ; ルートの場合
        MOV     EDADDR,CX               ;RuteDirEntryの先頭セクタ番号（下位）
        MOV     CX,RDESECW
        MOV     EDADDRH,CX              ;RuteDirEntryの先頭セクタ番号（上位）
LC_ELD: 
        MOV     DI,OFFSET DTAREA
        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        CALL    SD_READ                 ; data read 
        ;読み取りエラー処理省略
        XOR     BX,BX                   ; セクタ内ポインタ初期化

        ;Entryチェック
LC_EJ4: MOV     SI,OFFSET DTAREA
LC_EJ2: ADD     SI,BX
        MOV     AL,[SI]
        TEST    AL,AL                   ; 終端チェック
        JNZ     LC_EJ3
LC_EJ8: MOV     SI,0FFFFH
        JMP     LC_EJ9                  ; 終端のため終了

LC_EJ3: CMP     AL,0E5H                 ; 削除ファイルチェック
        JNZ     LC_EJA                  ; エントリ読み取りOK
LC_EJ7: ADD     BX,0020H                ; 次のNoのチェックへ
LC_EJ1: CMP     BX,0200H;512バイト分
        JB      LC_EJ4;(BX<0200H)

        MOV     AX,EDADDR
        MOV     BX,EDADDRH
        ADD     AX,0200H
        ADC     BX,0000H
        MOV     EDADDR,AX
        MOV     EDADDRH,BX
        TEST    AX,7FFFH                ; クラスタ超過チェック
        JNZ     LC_ELD
        ; クラスタを超えたためFATチェック
        SUB     AX,0200H
        SBB     BX,0000H
        CALL    LC_FATUPD
        MOV     EDADDR,AX
        MOV     EDADDRH,BX
        CMP     BX,0FFFFH
        JNZ     LC_ELD
        CMP     AX,0FFFFH
        JNZ     LC_ELD
        MOV     SI,0FFFFH
        JMP     LC_EJ9                  ; 終端のため終了

LC_EJA: ADD     BX,0020H                ; 次のNoへ
LC_EJ9: MOV     EDSRCO,BX               ; 現在のポインタをセーブ
        XOR     DL,DL                  ; error code 強制的に00Hにセット
        
        POP     DI
        POP     CX
        POP     BX
        POP     AX
        RET
;------------------------------------------------------------------------------
;Name : LC_FATCCSD (FATクラスタ番号から実セクタ番号を生成する)
;Input : AX -> FAT上のクラスタ番号
;Output : AX -> 実セクタ番号下位、BX ->  実セクタ番号上位
;         
;Description : FATクラスタ番号から実セクタ番号を生成する。
;------------------------------------------------------------------------------
LC_FATCCSD:
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI

        MOV     CX,RDESECL; RuteDirEntryの先頭セクタ番号（下位）
        MOV     DX,RDESECW; RuteDirEntryの先頭セクタ番号（上位）
        SUB     CX,8000H
        SBB     DX,0000H
        XOR     BX,BX
        SHR     AX,1
        RCR     BX,1
        ADD     BX,CX
        ADC     AX,DX
        XCHG    AX,BX
        AND     AX,8000H

        POP     DI
        POP     SI
        POP     DX
        POP     CX
        RET


;------------------------------------------------------------------------------
;Name : LC_FATUPD (FATから次のセクタ番号を取得する)
;Input : AX -> 現在のセクタ番号下位、BX ->  現在のセクタ番号上位
;Output : AX -> 次のセクタ番号下位、BX ->  次のセクタ番号上位
;         CX -> 次のクラスタ番号（FAT番号）
;Description : FATを見に行き次セクタ番号を取得する。無い場合はAX,BX->FFFFH
;------------------------------------------------------------------------------
LC_FATUPD:
        PUSH    DX
        PUSH    SI
        PUSH    DI

        MOV     DX,FATTCT
        SHL     AX,1
        RCL     BX,1
        SUB     BX,DX
        INC     BX;検索FAT番号を生成(BX)

        XOR     CX,CX
        SHL     BX,1
        RCL     CX,1
        MOV     AX,FATTSCL; FAT1の先頭セクタ番号（下位）
        MOV     DX,FATTSCW; FAT1の先頭セクタ番号（上位）
        ADD     AX,BX
        ADC     DX,CX
        MOV     BX,DX
        MOV     CX,AX
        AND     AX,0FE00H
        MOV     DI,OFFSET FATDATA
        CALL    SD_READ                 ; data read
        AND     CX,01FFH
        ADD     DI,CX
        MOV     AX,[DI]
        MOV     CX,AX
        CALL    LC_FATCCSD

LC_FU2: 
        POP     DI
        POP     SI
        POP     DX
        RET

;------------------------------------------------------------------------------
;Name : LC_FATSFC (FATから次のFAT番号を取得する)
;Input : AX -> 調べたいFAT番号
;Output : AX -> 次のFAT番号
;Description : FATを見に行き次のFAT番号を取得する。無い場合はAX->FFFFH
;------------------------------------------------------------------------------
LC_FATSFC:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI

        TEST    AX,AX
        JNZ     LC_FC1
        MOV     AX,0FFFFH
        JMP     LC_FCE
LC_FC1:
        PUSH    AX

        XOR     AL,AL
        XOR     CX,CX
        SAL     AX,1
        RCL     CX,1
        MOV     DX,FATTSCL; FAT1の先頭セクタ番号（下位）
        MOV     BX,FATTSCW; FAT1の先頭セクタ番号（上位）
        ADD     AX,DX
        ADC     BX,CX
        MOV     DI,OFFSET DTAREA
        CALL    SD_READ                 ; FAT data read 

        POP     AX
        SAL     AX,1
        AND     AX,01FFH
        ADD     DI,AX
        MOV     AX,[DI]
LC_FCE:
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX

        RET

;------------------------------------------------------------------------------
;Name : LC_FATFSC (一番番号が若い空きFAT番号を取得する。)
;Input : AL -> 00H初めから　それ以外はFATFENの続きから
;Output : AX -> 空きFAT番号（FAT上のクラスタ番号）
;        
;Description : FATを見に行き空きFAT番号を取得する。無い場合はAX->FFFFH
;              FATFENは更新される
;------------------------------------------------------------------------------
LC_FATFSC:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI

        TEST    AL,AL
        JNZ     LC_FS4
        ;初めから検索
        MOV     AX,FATTSCL; FAT1の先頭セクタ番号（下位）
        MOV     FATWKL,AX
        MOV     AX,FATTSCW; FAT1の先頭セクタ番号（上位）
        MOV     FATWKH,AX

        MOV     AX,FATANUM;全クラスタ数
        XOR     DX,DX
        MOV     BX,256
        DIV     BX;AX←FATが保存されているセクタ数
        MOV     BX,AX
        XOR     AX,AX;クラスタ番号抽出カウンタ
        XOR     SI,SI
        JMP     LC_FS3

LC_FS4: ;途中から検索
        MOV     AX,FATFEN
        XOR     DX,DX
        SAL     AX,1
        RCL     DX,1
        MOV     SI,AX
        MOV     BX,FATTSCL; FAT1の先頭セクタ番号（下位）
        MOV     CX,FATTSCW; FAT1の先頭セクタ番号（上位）
        AND     AX,0FE00H
        ADD     AX,BX
        ADC     DX,CX
        MOV     FATWKL,AX
        MOV     FATWKH,DX

        MOV     AX,FATANUM;全クラスタ数
        MOV     BX,FATFEN;クラスタ番号抽出カウンタ
        SUB     AX,BX
        XOR     DX,DX
        MOV     BX,256
        DIV     BX;AX←FATが保存されているセクタ数
        MOV     BX,AX
        MOV     AX,FATFEN;クラスタ番号抽出カウンタ

LC_FS3: MOV     DI,OFFSET DTAREA
        PUSH    AX
        PUSH    BX
        MOV     AX,FATWKL
        MOV     BX,FATWKH
        CALL    SD_READ                 ; data read 
        ADD     AX,0200H
        ADC     BX,0000H
        MOV     FATWKL,AX
        MOV     FATWKH,BX

        MOV     CX,256
        MOV     AX,SI
        SHR     AX,1
        SHR     AX,1
        AND     AX,00FFH
        SUB     CX,AX
        MOV     DI,OFFSET DTAREA
        AND     SI,01FFH
        ADD     DI,SI
        POP     BX
        POP     AX
        XOR     SI,SI
        
LC_FS2: MOV     DX,[DI]
        ADD     DI,2
        TEST    DX,DX;空きクラスタチェック
        JZ      LC_FS1;空いていたらジャンプ
        INC     AX;クラスタ番号増やす
        DEC     CX
        JNZ     LC_FS2;セクタ超えていないか
        DEC     BX
        JNZ     LC_FS3;FAT終端までチェックしたか
        MOV     AX,0FFFFH;空き無し
;        JMP     LC_FSE

LC_FS1: MOV     FATFEN,AX;一番若い空きクラスタ番号を保持

LC_FSE:
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX

        RET
FATWKL  DW       1 DUP(?)
FATWKH  DW       1 DUP(?)

;------------------------------------------------------------------------------
;Name : LC_FATMCN (指定したFAT番号に新しいをFAT番号を付与してチェーンを作る)
;Input : AX -> 更新するFAT番号
;Output : AX -> 付与先の新しいFAT番号   ->0FFFFH 失敗
;         
;Description : 指定されたFAT番号に次のFAT番号を付与しチェーンを作る。
;              指定番号のFAT番号がFFFFでなければエラーを返す。
;              指定番号のFAT番号が0000だったら新規ファイルとしてクラスタを割り
;              当てる
;              FATFENも更新される。
;------------------------------------------------------------------------------
LC_FATMCN:
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI

        TEST    AX,AX;AXが0000Hだったら新規ファイル
        JZ      LC_MC2

        MOV     SI,AX
        XOR     DX,DX
        SAL     AX,1
        RCL     DX,1
        AND     AX,0FE00H

        MOV     CX,FAT2SCL; FAT2の先頭セクタ番号（下位）
        MOV     BX,FAT2SCW; FAT2の先頭セクタ番号（上位）
        ADD     CX,AX
        ADC     BX,DX
        MOV     FA2MCL,CX
        MOV     FA2MCH,BX

        MOV     CX,FATTSCL; FAT1の先頭セクタ番号（下位）
        MOV     BX,FATTSCW; FAT1の先頭セクタ番号（上位）
        ADD     AX,CX
        ADC     BX,DX
        MOV     FATMCL,AX
        MOV     FATMCH,BX

        MOV     DI,OFFSET DTAREA
        CALL    SD_READ                 ; data read 
        MOV     BX,SI
        SAL     BX,1
        AND     BX,01FFH
        MOV     DX,[DI+BX]
        CMP     DX,0FFFFH
        JZ      LC_MC0;チェーン終端かチェック
        MOV     BX,0FFFFH;エラー
        JMP     LC_MCE

LC_MC0: MOV     CX,FATFEN
        MOV     [DI+BX],CX;空いてるFAT番号を入れる
        AND     CX,0FF00H
        MOV     AX,SI
        AND     AX,0FF00H
        CMP     AX,CX;同じセクタであるか比較
        JZ      LC_MC1
        MOV     AX,FATMCL
        MOV     BX,FATMCH
        CALL    SD_WRITE; FAT1 data write 
        MOV     AX,FAT2SCL
        MOV     BX,FAT2SCW
        CALL    SD_WRITE; FAT2 data write

LC_MC2: MOV     AX,FATFEN
        XOR     DX,DX
        SAL     AX,1
        RCL     DX,1
        AND     AX,0FE00H
        MOV     CX,FAT2SCL; FAT2の先頭セクタ番号（下位）
        MOV     BX,FAT2SCW; FAT2の先頭セクタ番号（上位）
        ADD     CX,AX
        ADC     BX,DX
        MOV     FA2MCL,CX
        MOV     FA2MCH,BX
        MOV     CX,FATTSCL; FAT1の先頭セクタ番号（下位）
        MOV     BX,FATTSCW; FAT1の先頭セクタ番号（上位）
        ADD     AX,CX
        ADC     BX,DX
        MOV     FATMCL,AX
        MOV     FATMCH,BX
        MOV     DI,OFFSET DTAREA
        CALL    SD_READ                 ; data read 
LC_MC1: MOV     BX,FATFEN
        SAL     BX,1
        AND     BX,01FFH
        MOV     [DI+BX],0FFFFH
        MOV     AX,FATMCL
        MOV     BX,FATMCH
        CALL    SD_WRITE                ; FAT data write 
        MOV     AX,FAT2SCL
        MOV     BX,FAT2SCW
        CALL    SD_WRITE; FAT2 data write

        ;次の空きクラスタを検索しFATFENを更新
        MOV     BX,FATFEN
        MOV     AL,01H
        CALL    LC_FATFSC
        MOV     AX,BX
             
LC_MCE:
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX

        RET
FATMCL  DW       1 DUP(?)
FATMCH  DW       1 DUP(?)
FA2MCL  DW       1 DUP(?)
FA2MCH  DW       1 DUP(?)

;------------------------------------------------------------------------------
;Name : LC_CHKPAT (パスチェック）
;Input : 
;Output : CarryFlag -> error status(0 -> OK, FF -> NG)
;Description : パケットからきたパスと現在のパスとを比較
;------------------------------------------------------------------------------
LC_CHKPAT:
        PUSH    ES
        PUSH    DS
        LES     DI,DWORD PTR CS:[PAKET_FCB]     ;GET FCB ENTRY
        LES     DI,DWORD PTR ES:[DI][PATH_P]    ;GET PATH ENTRY
        XOR     AL,AL
        MOV     SI,DI
        MOV     CX,0FFFFH
        REPNZ   SCASB
        NOT     CX
        MOV     DI,SI

        MOV     SI,CS
        MOV     DS,SI
        MOV     SI,OFFSET PATHBUF

LC_DI1: CMPSB
        JNZ     LC_DI0
        LOOP    LC_DI1
        CLC                             ; パスが同じである
        JMP     LC_DI2
LC_DI0: STC                             ; パスが違っている
LC_DI2: POP     DS
        POP     ES
        RET
;------------------------------------------------------------------------------
;Name : LC_PATCOP (パスコピー）
;Input : 
;Output : 
;Description : パケットからきたパスを現在のパスに設定
;------------------------------------------------------------------------------
LC_PATCOP:
        PUSH    ES
        PUSH    DS
        LES     DI,DWORD PTR CS:[PAKET_FCB]     ;GET FCB ENTRY
        LES     DI,DWORD PTR ES:[DI][PATH_P]    ;GET PATH ENTRY
        XOR     AL,AL
        MOV     CX,0FFFFH
        REPNZ   SCASB
        NOT     CX

        LDS     SI,DWORD PTR CS:[PAKET_FCB]     ;GET FCB ENTRY
        LDS     SI,DWORD PTR DS:[SI][PATH_P]    ;GET PATH ENTRY

        MOV     DI,OFFSET PATHBUF
        MOV     AX,CS
        MOV     ES,AX

        REP     MOVSB

        POP     DS
        POP     ES
        RET
;------------------------------------------------------------------------------
;Name : LC_SRCSUB (サブディレクトリ検索）
;Input : 
;Output : CarryFlag -> error status(0 -> OK, FF -> NG)
;Description : パケットで指定されているサブディレクトリを検索する
;------------------------------------------------------------------------------
LC_SRCSUB:
        PUSH    ES
;        PUSH    DS

        LES     SI,DWORD PTR CS:[PAKET_FCB]     ;GET FCB ENTRY
        LES     SI,DWORD PTR ES:[SI][PATH_P]    ;GET PATH ENTRY

        CMP     BYTE PTR ES:[SI],00H    ; ルートかチェック
        JNZ     LC_UJ6
        XOR     AX,AX                   ; ルートの場合
        MOV     SDCLUS,AX               ; 
        MOV     AX,RDESECL
        MOV     SDESECL,AX              ;現在のSubDirの先頭セクタ番号（下位）
        MOV     AX,RDESECW
        MOV     SDESECW,AX              ;現在のSubDirの先頭セクタ番号（上位）
        JMP     LC_UJ4

LC_UJ6: MOV     AX,SDCLUS
        MOV     SDCLBF,AX;退避
        MOV     AX,SDESECL
        MOV     SDESBFL,AX;退避
        MOV     AX,SDESECW
        MOV     SDESBFW,AX;退避
        XOR     AX,AX
        MOV     SDCLUS,AX               ; 初期化
        MOV     AX,RDESECL
        MOV     SDESECL,AX              ;現在のSubDirの先頭セクタ番号（下位）
        MOV     AX,RDESECW
        MOV     SDESECW,AX              ;現在のSubDirの先頭セクタ番号（上位）

LC_UL3: PUSH    ES                      ; 20Hクリア
        MOV     AX,CS
        MOV     ES,AX
        MOV     AL,20H
        MOV     DI,OFFSET PATHWOK
        MOV     CX,11
        REP     STOSB
        POP     ES

        MOV     CL,11                   ; パス転送
        MOV     DI,OFFSET PATHWOK
LC_UJ0: MOV     AL,ES:[SI]
        CMP     AL,'\'
        JZ      LC_UJ1
        CMP     AL,00H
        JZ      LC_UJ1
        MOV     [DI],AL
        INC     SI
        INC     DI
        DEC     CL
        JNZ     LC_UJ0

LC_UJ1: PUSH    SI
        PUSH    ES
        MOV     AX,CS
        MOV     ES,AX
        XOR     AL,AL                   ; 一番最初のED検索
        JMP     LC_UL2

LC_UL1: MOV     AL,01H
LC_UL2: CALL    LC_SRCEDR
        CMP     SI,0FFFFH
        JZ      LC_UJ5                  ; EDなし
        TEST    BYTE PTR [SI+11],10H    ; 属性比較（ディレクトリかチェック）
        JZ      LC_UL1                  ; ディレクトリではない場合とばす
        MOV     DI,OFFSET PATHWOK
        MOV     CX,11
LC_UL0: MOV     AL,[DI]
        CMP     [SI],AL
        JNZ     LC_UL1                  ; 違っていたら
        INC     SI
        INC     DI
        LOOP    LC_UL0

        MOV     BX,[SI+15]
        MOV     SDCLUS,BX
        DEC     BX
        MOV     AX,FATTCT
        ADD     AX,BX
        MOV     CX,8000H
        MUL     CX
        MOV     SDESECL,AX              ;現在のSubDirの先頭セクタ番号（下位）
        MOV     SDESECW,DX              ;現在のSubDirの先頭セクタ番号（上位）

        POP     ES                      ; 合っていたら
        POP     SI
        MOV     AL,ES:[SI]
        INC     SI
        CMP     AL,'\'                  ; 続きがあるかチェック
        JZ      LC_UL3
        CMP     AL,00H                  ; 終端かチェック
        JZ      LC_UJ4
        JMP     LC_UJ2                  ; それ以外は不正パス
        
LC_UJ5: POP     ES
        POP     SI
LC_UJ2: MOV     AX,SDCLBF               ; 退避していたのを元に戻す
        MOV     SDCLUS,AX
        MOV     AX,SDESBFL
        MOV     SDESECL,AX              ;現在のSubDirの先頭セクタ番号（下位）
        MOV     AX,SDESBFW
        MOV     SDESECW,AX              ;現在のSubDirの先頭セクタ番号（上位）

        STC                             ; 指定のパスが不正
        JMP     LC_UJ3

LC_UJ4: CLC                             ; パス設定OK
LC_UJ3: ;POP     DS
        POP     ES
        RET

;------------------------------------------------------------------------------
;Name : 以下ファイル操作関係サブルーチン
;Description : 
;------------------------------------------------------------------------------

;----- GET FILE HANDLE -----

G_FHAND:
	PUSH	ES
	PUSH	DI
	PUSH	CX

	MOV	AX,CS
	MOV	ES,AX
	MOV	DI,OFFSET HANDLE
	MOV	CX,10
	XOR	AL,AL
	REPNZ   SCASB
	JZ	G_F_JP1

	POP	CX
	POP	DI
	POP	ES
	MOV	AL,4			;Too many open files
	STC
	RET

G_F_JP1:
	DEC	DI
	DEC	AL
	MOV	ES:[DI],AL
	MOV	AL,9
	SUB	AL,CL

	POP	CX
	POP	DI
	POP	ES
        CLC
	RET

;----- RESET FILE HANDLE -----

R_FHAND:
	PUSH	DI

	MOV	DI,OFFSET HANDLE
	XOR	AH,AH
	CMP	AL,10
	JNC	R_F_ER1
	ADD	DI,AX
	MOV	CS:[DI],AH

R_F_ER1:
	POP	DI
	RET

;----- CHECK FILE HANDLE -----
C_FHAND:
        PUSH    DI
        PUSH    AX
        MOV     DI,OFFSET HANDLE
        XOR     AH,AH
        ADD     DI,AX
        MOV     AL,[DI]
        TEST    AL,AL
        JZ      C_F_ER1
        STC
        JMP     C_F_ER2
C_F_ER1:
        CLC
C_F_ER2:
        POP     AX
        POP     DI
        RET

;----- FILE POINTER MOVE -----

P_MOVE:
        LES     BX,DWORD PTR [PAKET_FCB]

        MOV     AL,ES:[BX][S_HANDL]
        MOV     AH,HNDANM
        MUL     AH
        MOV     DI,OFFSET FADDRE
        ADD     DI,AX

        MOV     AX,ES:[BX][POINT]
        CMP     ES:[BX][S_POINT],AX
        JNZ     P_M_JP1
        CMP     [DI+5],AX
        JNZ     P_M_JP1
        MOV     AX,ES:[BX][POINT][2]
        CMP     ES:[BX][S_POINT][2],AX
        JNZ     P_M_JP1
        CMP     [DI+7],AX
        JNZ     P_M_JP1
        RET                             ;FILE-POINTER MOVE CANSEL
P_M_JP1:
        MOV     AX,ES:[BX][POINT]
        MOV     CX,ES:[BX][POINT][2]
        SHL     AX,1
        RCL     CX,1
        MOV     BX,[DI+5]
        MOV     DX,[DI+7]
        SHL     BX,1
        RCL     DX,1
        CMP     CX,DX;同じクラスタ内ならクラスタ検索しない
        JZ      P_M_J6

        INC     CX
        MOV     AX,[DI+2];最初のクラスタ更新
P_M_J5: MOV     BX,AX
        CALL    LC_FATSFC
        CMP     AX,0FFFFH
        JZ      P_M_J4
        LOOP    P_M_J5
P_M_J4: MOV     [DI+9],BX
P_M_J6: LES     BX,DWORD PTR [PAKET_FCB]
        MOV     AX,ES:[BX][POINT]
        MOV     DX,ES:[BX][POINT][2]
        MOV     [DI+5],AX        ; 移動したポインタを保存
        MOV     [DI+7],DX

        RET


        MOV     AX,ES:[BX][POINT]
        MOV     DX,ES:[BX][POINT][2]
        MOV     CX,[DI+13]              ; ポインタのオーバーランチェック
        CMP     DX,CX
        JC      P_M_J3
        MOV     CX,[DI+11]
        CMP     AX,CX
        JC      P_M_J3
;        JMP     P_M_ER1                 ; ポインタがサイズをオーバーしている
        MOV     AX,[DI+11]               ; ポインタがサイズをオーバーしている
        MOV     DX,[DI+13]
P_M_J3: 
        MOV     [DI+5],AX        ; 移動したポインタを保存
        MOV     [DI+7],DX
P_M_J7:
        RET

P_M_ER1:
        MOV     AX,5                    ;Can't accress
P_M_ER2:
        POP     BX                      ;SP FLASH (CALL)
        JMP     ERR_EXIT


;----- FILE POINTER SAVE -----

P_SAVE:
	LES	BX,DWORD PTR [PAKET_FCB]
	MOV	AX,ES:[BX][POINT]
	MOV	ES:[BX][S_POINT],AX
	MOV	AX,ES:[BX][POINT][2]
	MOV	ES:[BX][S_POINT][2],AX	;POINTER SAVE
	RET


;----- PATH SETING -----
PATH_SET:
        CALL    LC_CHKPAT
        JNC     PA_J00                  ; パスが同じ
        CALL    LC_SRCSUB               ; パス検索
        JC      PA_E00
        CALL    LC_PATCOP               ; パスを更新
PA_J00: CLC
PA_E00: RET


;###### SDCard Control Routine ################################################
;------------------------------------------------------------------------------
;Name : SD_CsL (チップセレクトLOW)
;Input : なし
;Output : なし
;Description : セントロニクス線STBラインをローにしSDカードのCS信号をローにする
;------------------------------------------------------------------------------
SD_CsL:
        PUSHA
        MOV     AH,2BH
        MOV     BL,PT_STB;STB wo LOW
        INT     41H
        POPA
        RET
;------------------------------------------------------------------------------
;Name : SD_CsH (チップセレクトHIGHT)
;Input : なし
;Output : なし
;Description : セントロニクス線STBラインをハイにしSDカードのCS信号をハイにする
;------------------------------------------------------------------------------
SD_CsH:
        PUSHA
        MOV     AH,2AH
        MOV     BL,PT_STB;STB wo HIGHT
        INT     41H
        POPA
        RET
;------------------------------------------------------------------------------
;Name : SD_SD1B (１バイト送信)
;Input : DH <-- SEND DATA
;Output : なし
;Description : SDカードにDHレジスタのデータを送る
;------------------------------------------------------------------------------
SD_SD1B:
        PUSH    AX
        PUSH    BX
        PUSH    CX

        MOV     BH,DH
        MOV     DX,0241H
        IN      AL,DX
        MOV     CL,4
        SHR     AL,CL
        
        MOV     DX,0240H
        OR      AL,80H

        OR      AL,04H;RTS HIGHT
        SHL     BH,1
        JB      SD1BJ1
        AND     AL,0FBH;RTS LOW
SD1BJ1: OUT     DX,AL
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL

        OR      AL,04H;RTS HIGHT
        SHL     BH,1
        JB      SD1BJ2
        AND     AL,0FBH;RTS LOW
SD1BJ2: OUT     DX,AL
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL

        OR      AL,04H;RTS HIGHT
        SHL     BH,1
        JB      SD1BJ3
        AND     AL,0FBH;RTS LOW
SD1BJ3: OUT     DX,AL
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL

        OR      AL,04H;RTS HIGHT
        SHL     BH,1
        JB      SD1BJ4
        AND     AL,0FBH;RTS LOW
SD1BJ4: OUT     DX,AL
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL

        OR      AL,04H;RTS HIGHT
        SHL     BH,1
        JB      SD1BJ5
        AND     AL,0FBH;RTS LOW
SD1BJ5: OUT     DX,AL
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL

        OR      AL,04H;RTS HIGHT
        SHL     BH,1
        JB      SD1BJ6
        AND     AL,0FBH;RTS LOW
SD1BJ6: OUT     DX,AL
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL

        OR      AL,04H;RTS HIGHT
        SHL     BH,1
        JB      SD1BJ7
        AND     AL,0FBH;RTS LOW
SD1BJ7: OUT     DX,AL
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL

        OR      AL,04H;RTS HIGHT
        SHL     BH,1
        JB      SD1BJ8
        AND     AL,0FBH;RTS LOW
SD1BJ8: OUT     DX,AL
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL

        POP     CX
        POP     BX
        POP     AX
        RET
;------------------------------------------------------------------------------
;Name : SD_RV1B (１バイト受信)
;Input : なし
;Output : DH --> RECV DATA
;Description : SDカードから１バイト受信しDHレジスタに格納する
;------------------------------------------------------------------------------
SD_RV1B:
        PUSH    AX
        PUSH    BX
        PUSH    CX

        MOV     DX,0241H
        IN      AL,DX
        MOV     CL,4
        SHR     AL,CL
        
        MOV     DX,0240H
        OR      AL,80H

        OR      AL,04H;RTS HIGHT
        OUT     DX,AL

        XOR     BH,BH

        ; 1st
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 2st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 3st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 4st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 5st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 6st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 7st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 8st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        MOV     DH,BH

        POP     CX
        POP     BX
        POP     AX
        RET

;ブロック受信
;CX <-- DATA LENGTH
;DI <-- DATA POINTER
;DH --> RESULT
SD_RVBR:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI

        MOV     WORD PTR ABLOCK,CX

        MOV     CX,TIMEOUT
RVBR_L: CALL    SD_RV1B

        CMP     DH,DA_TOKEN
        JZ      SDBRJ2
        LOOP    RVBR_L
        MOV     DH,0FFH;FALSE END
        JMP     SDBRJ3;TIME OUT
SDBRJ2: 
        MOV     DX,0241H
        IN      AL,DX
        MOV     CL,4
        SHR     AL,CL
        OR      AL,80H

        MOV     DX,0240H
        OR      AL,04H;RTS HIGHT
        OUT     DX,AL

        MOV     CX,WORD PTR ABLOCK
RVBRL1: ;CALL    SD_RV1B
        XOR     BH,BH
        
        ; 1st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 2st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 3st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 4st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 5st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 6st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 7st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH

        ; 8st
        MOV     DX,0240H
        AND     AL,0F7H;DTR LOW
        OUT     DX,AL
        OR      AL,08H;DTR HIGHT
        OUT     DX,AL
        MOV     AH,AL
        MOV     DX,0241H
        IN      AL,DX
        SHR     AL,1
        RCL     BH,1
        MOV     AL,AH


        MOV     [DI],BH
        INC     DI
        DEC     CX
        JZ      SDBRJ4
        JMP     RVBRL1
SDBRJ4:
        CALL    SD_RV1B
        CALL    SD_RV1B
        XOR     DH,DH;TRUE END

SDBRJ3: POP     DI
        POP     CX
        POP     BX
        POP     AX
        RET

;------------------------------------------------------------------------------
;Name : SD_TKSD (コマンドトークン送信)
;Input : DI <-- DATA POINTER
;Output : DH --> RESULT
;Description : SDカードにコマンドトークン（６バイト）を送る
;------------------------------------------------------------------------------
SD_TKSD:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI

        MOV    CX,6
TKSD_L: MOV    DH,[DI]
        CALL   SD_SD1B
        INC    DI
        LOOP   TKSD_L

        MOV     CX,TIMEOUT
TKSDL2:
        CALL    SD_RV1B
        TEST    DH,80H
        JZ      TKSDJ2
        LOOP    TKSDL2
        MOV     DH,0FFH;FALSE END TIME OUT
TKSDJ2:
        POP     DI
        POP     CX
        POP     BX
        POP     AX
        RET
;------------------------------------------------------------------------------
;Name : SD_STBLN (ブロック長設定)
;Input : CX <-- BlockLen
;Output : DH --> RESULT
;Description : SDカードにコマンド１６（ブロック長設定）を送り、CXで指定する
;             ブロック長に設定する
;------------------------------------------------------------------------------
SD_STBLN:
        PUSH    DI

        CALL    SD_CsL
        MOV     DI,OFFSET BLCMD
        MOV     BYTE PTR [DI],CMD16
        INC     DI
        MOV     BYTE PTR [DI],00H
        INC     DI
        MOV     BYTE PTR [DI],00H
        INC     DI
        MOV     BYTE PTR [DI],CH
        INC     DI
        MOV     BYTE PTR [DI],CL
        INC     DI
        MOV     BYTE PTR [DI],0FFH
        MOV     DI,OFFSET BLCMD
        CALL    SD_TKSD

        CALL    SD_DMMY

        CALL    SD_CsH

        POP     DI
        RET
;------------------------------------------------------------------------------
;Name : SD_DMMY (ダミーデータ送信)
;Input : なし
;Output : なし
;Description : SDカードにダミーデータを１バイト送る
;------------------------------------------------------------------------------
SD_DMMY:
        PUSH    DX

        CALL    SD_CsH
        MOV     DH,DUMMY_DT
        CALL    SD_SD1B
        CALL    SD_CsL

        POP     DX
        RET
;------------------------------------------------------------------------------
;Name : SD_GTCSD (CSDレジスタ値取得)
;Input : なし
;Output : DH --> RESULT
;Description : SDカードにコマンド９を送信しCSD情報を取得する。
;              CSD情報はSD_CSDに格納する。
;------------------------------------------------------------------------------
SD_GTCSD:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI

        CALL    SD_CsL
        MOV     DI,OFFSET BLCMD9
        CALL    SD_TKSD
        CMP     DH,00H
        JNZ     GTCSDJ
        MOV     DI,OFFSET SD_CSD
        MOV     CX,16
        CALL    SD_RVBR

GTCSDJ: CALL    SD_DMMY

        CALL    SD_CsH

        POP     DI
        POP     CX
        POP     BX
        POP     AX
        RET
;------------------------------------------------------------------------------
;Name : SD_GTCID (CIDレジスタ値取得)
;Input : なし
;Output : DH --> RESULT
;Description : SDカードにコマンド１０を送信しCID情報を取得する。
;              CSD情報はSD_CIDに格納する。
;------------------------------------------------------------------------------
SD_GTCID:
        PUSH    BX
        PUSH    CX
        PUSH    DI

        CALL    SD_CsL
        MOV     DI,OFFSET BLCMD10
        CALL    SD_TKSD
        CMP     DH,00H
        JNZ     GTCIDJ
        MOV     DI,OFFSET SD_CID
        MOV     CX,16
        CALL    SD_RVBR

GTCIDJ: CALL    SD_DMMY
        CALL    SD_CsH

        POP     DI
        POP     CX
        POP     BX
        RET
;------------------------------------------------------------------------------
;Name : SD_GTSTR (STATEレジスタ値取得)
;Input : なし
;Output : DH --> RESULT(R1) DL --> RESULT(R2)
;Description : SDカードにコマンド１３を送信しSTATE情報を取得する。
;------------------------------------------------------------------------------
SD_GTSTR:
        PUSH    BX
        PUSH    DI

        CALL    SD_CsL

        MOV     DI,OFFSET BLCMD13
        CALL    SD_TKSD
        MOV     DL,DH
        CALL    SD_RV1B
        XCHG    DH,DL

        CALL    SD_DMMY
        CALL    SD_CsH

        POP     DI
        POP     BX
        RET
;------------------------------------------------------------------------------
;Name : SD_READ (1ブロックデータ読み出し)
;Input : DI <-- DATA POINTER
;        AX <-- low lba
;        BX <-- hight lba
;Output :    ;DH --> RESULT
;Description : SDカードにコマンド１７を送信しAX,BXで指定したブロックのデータ
;             １ブロック分を取得する。
;------------------------------------------------------------------------------
SD_READ:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
        PUSH    SI

        CALL    SD_CsL
        MOV     CX,TIMEOUT
READL1:
        MOV     SI,DI
READL2: MOV     DI,OFFSET BLCMD
        MOV     BYTE PTR [DI],CMD17
        INC     DI
        MOV     BYTE PTR [DI],BH
        INC     DI
        MOV     BYTE PTR [DI],BL
        INC     DI
        MOV     BYTE PTR [DI],AH
        INC     DI
        MOV     BYTE PTR [DI],AL
        INC     DI
        MOV     BYTE PTR [DI],0FFH
        MOV     DI,OFFSET BLCMD
        CALL    SD_TKSD
        CMP     DH,00H
        JZ      READJ1
        CALL    SD_CsH
        MOV     DH,DUMMY_DT
        CALL    SD_SD1B
        CALL    SD_CsL
        LOOP    READL2
        JMP     READJ2
READJ1:
        MOV     DI,SI
        MOV     CX,512;ブロックサイズ
        CALL    SD_RVBR

READJ2:
        CALL    SD_CsH
        MOV     DH,0FFH
        CALL    SD_SD1B
        CALL    SD_CsL

        CALL    SD_CsH

        POP     SI
        POP     DI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

LBALOW  DW      1 DUP(?)
LBAHIG  DW      1 DUP(?)
LBACUT  DB      1 DUP(?)
;------------------------------------------------------------------------------
;Name : SD_WRITE (1ブロックデータ書き込み)
;Input : DI <-- DATA POINTER
;        AX <-- low lba
;        BX <-- hight lba
;Output :    ;DH --> RESULT
;Description : SDカードにコマンド２４を送信しAX,BXで指定したブロックにデータ
;             １ブロック分を書き込む。
;------------------------------------------------------------------------------
SD_WRITE:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
        PUSH    SI

        CALL    SD_CsL

        MOV     SI,DI

        MOV     CX,TIMEOUT
WRTEL1: MOV     DI,OFFSET BLCMD
        MOV     BYTE PTR [DI],CMD24
        INC     DI
        MOV     BYTE PTR [DI],BH
        INC     DI
        MOV     BYTE PTR [DI],BL
        INC     DI
        MOV     BYTE PTR [DI],AH
        INC     DI
        MOV     BYTE PTR [DI],AL
        INC     DI
        MOV     BYTE PTR [DI],0FFH
        MOV     DI,OFFSET BLCMD
        CALL    SD_TKSD
        CMP     DH,00H
        JZ      WRTEJ1
        CALL    SD_DMMY
        LOOP    WRTEL1
        JMP     WRTEJ2
WRTEJ1:
        MOV     DH,DA_TOKEN
        CALL    SD_SD1B
        MOV     CX,512;ブロックサイズ
WRTEL2: MOV     DH,[SI]
        CALL    SD_SD1B
        INC     SI
        LOOP    WRTEL2
        MOV     DH,DUMMY_DT
        CALL    SD_SD1B;dummy crc
        CALL    SD_SD1B;dummy crc

        MOV     CX,TIMEOUT
WRTEL3: CALL    SD_RV1B
        AND     DH,0FH;
        CMP     DH,05H;write true?
        JZ      WRTEJ3
        LOOP    WRTEL3
        MOV     DH,0FFH;
        JMP     WRTEJ2
WRTEJ3: MOV     CX,0800H
WRTEL4: CALL    SD_RV1B;bussy check
        CMP     DH,00H
        JNZ     WRTEJ4
        LOOP    WRTEL4
        MOV     DH,0FFH
        JMP     WRTEJ2
WRTEJ4: MOV     DH,00H
WRTEJ2: 
        CALL    SD_DMMY

        CALL    SD_CsH

        POP     SI
        POP     DI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET
;------------------------------------------------------------------------------
;Name : SD_CINIT (初期設定、SPIモード移行)
;Input : なし
;Output : DH --> RESULT
;Description : SDカードを動かすための初期化プロセス
;              コマンド０、コマンド８、コマンド５８、コマンド５５、コマンドA41
;             コマンド５８を発行
;------------------------------------------------------------------------------
SD_CINIT:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI
        PUSH    SI

        CALL    SD_CsH
        MOV     CX,10
        MOV     DH,DUMMY_DT
CINIL1: CALL    SD_SD1B;ClockDummySend
        LOOP    CINIL1

        CALL    SD_CsL

        MOV     CX,TIMEOUT
CINIL3: MOV     DI,OFFSET BLCMD0
        CALL    SD_TKSD
        CMP     DH,01H
        JZ      CINIJ2
        LOOP    CINIL3
        MOV     DH,0FFH;TIME OUT
        JMP     CINIJ1
CINIJ2:
        MOV     CX,TIMEOUT
CINIL2:
        CALL    SD_DMMY

;        MOV     DI,OFFSET BLCMD1
;        CALL    SD_TKSD
;        CMP     DH,00H
;        JZ      CINJX
;        LOOP    CINIL2
;        JMP     CINIJR
;CINJX:  JMP     CINIJR;B

        MOV     DI,OFFSET BLCMD8
        CALL    SD_TKSD
        CMP     DH,01H
        JZ      CINIJ1
        LOOP    CINIL2
        JMP     CINIJR
CINIJ1:
        CALL    SD_RV1B
        CALL    SD_RV1B
        CALL    SD_RV1B
        CALL    SD_RV1B

        MOV     CX,TIMEOUT
CINIJ3: CALL    SD_DMMY

        MOV     DI,OFFSET BLCMD58
        CALL    SD_TKSD
        CMP     DH,01H
        JZ      CINIJA
        LOOP    CINIJ3
        JMP     CINIJR;TIME OUT
CINIJA: CALL    SD_RV1B
        CALL    SD_RV1B
        CALL    SD_RV1B
        CALL    SD_RV1B

        MOV     CX,TIMEOUT
CINIJ4: CALL    SD_DMMY

        MOV     DI,OFFSET BLCMD55
        CALL    SD_TKSD

        CALL    SD_DMMY

        MOV     DI,OFFSET BLACD41
        CALL    SD_TKSD

        CMP     DH,00H
        JZ      CINIJ5
        LOOP    CINIJ4
        JMP     CINIJR;TIME OUT
CINIJ5:
        MOV     CX,TIMEOUT
CINIJB:
        CALL    SD_DMMY

        MOV     DI,OFFSET BLCMD58
        CALL    SD_TKSD
        CMP     DH,00H
        JZ      CINIJ7
        LOOP    CINIJB
        JMP     CINIJR;TIME OUT
CINIJ7: CALL    SD_RV1B
        CALL    SD_RV1B
        CALL    SD_RV1B
        CALL    SD_RV1B

CINIJR:
        CALL    SD_DMMY

        CALL    SD_CsH
        POP     SI
        POP     DI
        POP     CX
        POP     BX
        POP     AX
        RET
;------------------------------------------------------------------------------
;Name : SD_CINI2 (初期設定２、カード容量計算をする)
;Input : なし
;Output : DH --> RESULT
;Description : SDカードのCSD情報を読み出しカード容量を計算する
;------------------------------------------------------------------------------
SD_CINI2:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI
        PUSH    SI

        XOR     DX,DX
        MOV     C_SIZE,DX
        MOV     C_SIZEM,DL
        MOV     C_MULT,DX
        MOV     MAX_LBL,DX
        MOV     MAX_LBH,DX

        MOV     DI,OFFSET SD_CID
        CALL    SD_GTCID

        MOV     DI,OFFSET SD_CSD
        CALL    SD_GTCSD
        CMP     DH,00H
        JZ      CINJ21
        MOV     DH,0FEH
        JMP     CINJ22
CINJ21:
        ADD     DI,5
        MOV     CL,[DI]
        AND     CL,0FH
        MOV     AX,0001H
        SHL     AX,CL
        CMP     AX,512
        JZ      CINJ23
        CALL    SD_CsL
        MOV     CX,512
        CALL    SD_STBLN;set block n
        CALL    SD_CsH
        CMP     DH,00H
        JZ      CINJ24
        MOV     DH,0FDH
        JMP     CINJ22
CINJ24: MOV     DI,OFFSET SD_CSD
        CALL    SD_GTCSD
        CMP     DH,00H
        JZ      CINJ23
        MOV     DH,0FCH
        JMP     CINJ22
CINJ23: MOV     DI,OFFSET SD_CSD
        ADD     DI,6
        MOV     AH,[DI]
        AND     AH,03H
        INC     DI
        MOV     AL,[DI]
        SHL     AX,1
        SHL     AX,1
        INC     DI
        MOV     BL,[DI]
        AND     BL,0C0H
        MOV     CL,6
        SHR     BL,CL
        OR      AL,BL;AX=C_SIZE
        MOV     C_SIZE,AX
        INC     DI
        MOV     CL,[DI]
        AND     CL,03H
        INC     DI
        MOV     CH,[DI]
        SHL     CH,1
        RCL     CL,1;CL=C_SIZE_MULT
        MOV     C_SIZEM,CL
        ADD     CL,2
        MOV     AX,0001H
        SHL     AX,CL;AX=MULT
        MOV     C_MULT,AX
        MOV     DX,C_SIZE
        INC     DX
        MUL     DX;DX Total LBA block
        MOV     MAX_LBL,AX
        MOV     MAX_LBH,DX
CINJ22:
        POP     SI
        POP     DI
        POP     CX
        POP     BX
        POP     AX
        RET

;==============================================================================
;###### Data Area #############################################################
;----- MESSAGE ------------------------
TITLE_MSG:
        DB      'SDCard Driver Ver 2.00',13,10,'$'
TITLE_MSG2:
	DB	'SD DRIVE is E$'
TITLE_MSG3:
	DB	'SD CARD INIT OK',13,10,'$'
TITLE_MSG4:
	DB	'SD CARD INIT NG',13,10,'$'
TITLE_MSG5:
	DB	'SD CARD is FAT12',13,10,'$'
TITLE_MSG6:
	DB	'SD CARD is FAT32',13,10,'$'

;----- static area --------------------
DRIVENO DB      10                     ; DRIVE=E0:
SMFLAG  DB      1 DUP(?)               ; SM Flag
                                       ; b7 シリアルがあっていない
                                       ; b0 初期化チェック 1=OK 0=NG
; FAT関係
FSTSEC  DW      1 DUP(?)               ; MBR FirstSectorNum
SPCNUM  DB      1 DUP(?)               ; 1クラスタのセクタ数
FATNUM  DB      1 DUP(?)               ; FATの数(通常2)
RDENUM  DB      2 DUP(?)               ; ルートディレクトリエントリ数
                                       ; (1ディレクトリの最大ファイル数)
TSECTER DB      2 DUP(?)               ; ディスク領域の総セクタ数
                                       ; (0x10000以上の場合は0)
NFATNUM DB      2 DUP(?)               ; FAT1個のセクタ数
HSECTE1 DB      2 DUP(?)               ; ディスク領域の総セクタ数
HSECTE2 DB      2 DUP(?)               ; (0x10000以上の場合に利用)
FATTSCL DW      1 DUP(?)               ; FAT1の先頭セクタ番号（下位）
FATTSCW DW      1 DUP(?)               ; FAT1の先頭セクタ番号（上位）
FAT2SCL DW      1 DUP(?)               ; FAT2の先頭セクタ番号（下位）
FAT2SCW DW      1 DUP(?)               ; FAT2の先頭セクタ番号（上位）
RDESECL DW      1 DUP(?)               ; RuteDirEntryの先頭セクタ番号（下位）
RDESECW DW      1 DUP(?)               ; RuteDirEntryの先頭セクタ番号（上位）
FATTCT  DW      1 DUP(?)               ; ルートがあるクラスタの先頭クラスタ番号
FATUSEN DW      1 DUP(?)               ; 使用中FAT数を保存
FATANUM DW      1 DUP(?)               ; SDカードの全クラスタ数（FAT数）

;--------------------------------------
CHNAME  DB      11 DUP(?)
;----- Read Data ----------------------
DTAREA  DB      512 DUP(?)
DUMYDT  DB      0E5H; ファイル検索用ダミーデータ
RESAREA DB      4 DUP(?)
DTSTAR  DB      1 DUP(?)
BLSTAR  DB      1 DUP(?)
BLADAR1 DB      2 DUP(?)
ECCAR2  DB      3 DUP(?)
BLADAR2 DB      2 DUP(?)
ECCAR1  DB      3 DUP(?)
;----- ED検索用データ -----------------
EDADDR  DW      1 DUP(?)
EDADDRH DW      1 DUP(?)
EDSRCO  DW      1 DUP(?)
EDSRBL  DB      1 DUP(?)
SDESECL DW      1 DUP(?)               ;現在のSubDirの先頭セクタ番号（下位）
SDESECW DW      1 DUP(?)               ;現在のSubDirの先頭セクタ番号（上位）

;----- File Handle --------------------
HANDLE  DB      10 DUP(0)
        DB      0                      ; END OF DATA
;----- FileOpen情報 20*16 -------------
FADDRE  DW      1 DUP(?)               ;0 最後のクラスタ
FATADR  DW      1 DUP(?)               ;2 FAT上で最初のクラスタ位置
FASECT  DB      1 DUP(?)               ;4 現在のセクタ位置
FPOINT  DW      2 DUP(?)               ;5 ポインタ
FACLST  DW      1 DUP(?)               ;9 現在のクラスタ位置
FISIZE  DW      2 DUP(?)               ;11 ファイルのサイズ
FAAREV  DB      1 DUP(?)               ;15 予備
OPEDAL  DW      1 DUP(?)               ;16オープンファイルのEDAアドレス（下位）
OPEDAH  DW      1 DUP(?)               ;18オープンファイルのEDAアドレス（上位）
FADDRE1 DB      300 DUP(?)

;----- FAT Data -----------------------
FATSEG  DW      1 DUP(?)               ; FAT情報を格納するエリアセグメント情報
;FATSEC  DB      1 DUP(?)               ; 現在のFAT情報のセクタ情報
FATDATA DB      512 DUP(?)             ; FAT情報の読み込み用エリア（1セクタ分）

FATFEN  DW      1 DUP(?)               ; 空きクラスタで一番若いクラスタNOの保持

;----- PATH Buffer --------------------
PATHBUF DB      256 DUP(?)             ; 現在のパス
SDCLUS  DW      1 DUP(?)               ; 現在設定されているパスのサブディレクトリのクラスタ位置(FATの番号)
SDCLBF  DW      1 DUP(?)               ; 上の一時退避用
SDESBFL DW      1 DUP(?)               ;一時退避用SubDir先頭セクタ番号（下位）
SDESBFW DW      1 DUP(?)               ;一時退避用SubDir先頭セクタ番号（上位）
PATHWOK DB      11 DUP(?)              ; パス設定のワーク領域

;----- SDCard Control Data Area -------
ABLOCK  DW      1 DUP(?)
BLCMD   DB      6 DUP(?)
BLCMD0  DB      40H,00H,00H,00H,00H,95H
BLCMD1  DB      41H,00H,00H,00H,00H,0F9H
BLCMD8  DB      48H,00H,00H,01H,0AAH,87H
BLCMD9  DB      49H,00H,00H,01H,00H,0AFH
BLCMD10 DB      4AH,00H,00H,00H,00H,1BH
BLCMD12 DB      4CH,00H,00H,00H,00H,0FFH
BLCMD13 DB      4DH,00H,00H,00H,00H,0FFH
BLCMD16 DB      50H,00H,00H,00H,00H,15H
BLCMD17 DB      51H,00H,00H,00H,00H,055H
BLCMD24 DB      58H,00H,00H,00H,00H,0FFH
BLCMD42 DB      6AH,00H,00H,00H,00H,51H
BLCMD55 DB      77H,00H,00H,00H,00H,65H
BLCMD58 DB      7AH,00H,00H,00H,00H,0FDH
BLCMD59 DB      7BH,00H,00H,00H,00H,0FFH
;BLACD41 DB      69H,40H,0FFH,80H,00H,17H
BLACD41 DB      69H,00H,00H,00H,00H,0E5H
;BLACD41 DB      69H,00H,0FFH,80H,00H,85H
C_SIZE  DW      1 DUP(?)               ; カード容量　
C_SIZEM DB      1 DUP(?)               ; カード容量　乗数値
C_MULT  DW      1 DUP(?)               ; C_MULT=2^(C_SIZEM+2)
MAX_LBL DW      1 DUP(?)               ; カード総容量（下位４バイト）
MAX_LBH DW      1 DUP(?)               ; カード総容量（上位４バイト）
SD_CSD  DB      16 DUP(?)              ; SDCard CSD情報
SD_CID  DB      16 DUP(?)              ; SDCard CID情報
;==============================================================================
        END
;==============================================================================
