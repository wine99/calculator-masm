; ��A��������+��
; ��B��������-��
; ��C��������*�� 
; ��D�����������š� 
; ��E��������=�� 
; ��F��������ʼ���㣨�����������㣩����Ļ��ʾ��0����
;
; ����Ҫ�� 
;     �� ������������ݣ�С����λ����������ܸ�����ʾ�� 
;     �� ����+������-������*�������š�ʱ����ǰ��ʾ���ݲ��䡣 
;     �� ����������ʱ������ܸ�����ʾ�� 
;     �� ����E��ʱ����ʾ���ս�����ݡ���������Ϊ�����������1����ɫ��������ܣ���������1���
;     ����Ӳ��ʵ�֣���˸����������Ϊż���������2����ɫ��������ܣ���������2������Ӳ��ʵ�֣���
;     ˸�� 
;     �� ����F����������ĸ�����������ұߣ���Ӧ��λ������һ����ʾ��0����������������ʾ���ݡ�
;     ͬʱϨ������ķ�������ܣ��ȴ���һ������Ŀ�ʼ�� 
;     �� ��Ҫ������������ȼ����⡣ 
;     �� ����ֻ�������������㣬�����Ǹ�����ʵ�����㡣���ſ��Բ�����Ƕ���������������ʵ����ʽ
;     �д��ڶ���ƽ�����ŵļ��㡣
;
; ���˵���� 
;     ��������ʱ����������ʾ��Χ����Ӧ�������֡��ڼ�����������ʾ��Χʱ������ʾ��F����


code    segment
        assume cs:code

org  1200h
start:

    jmp true_start
    ; �жϿ����� 8259
    ; 8259ֻ��������8253�ļ�ʱ�ж�
    port59_0    equ 0ffe4h
    port59_1    equ 0ffe5h
    icw1        equ 13H         ; ���ش���
    icw2        equ 08h         ; �ж����ͺ� 08H 09H ...
    icw4        equ 09h         ; ȫǶ�ף������Ƭ�����Զ�EOI��8086/88ģʽ ΪʲôҪ�û��嵥Ƭ?
    ocw1open    equ 0feh        ; IRQ0�����ͺ�Ϊ08h
    vectorOffset EQU 20H        ; �ж������ĵ�ַ 08H*4=20H
    vectorSeg   EQU 22H         ; �ж�������CS�ε�ַ���ж��������еĵ�ַ��ֵΪ0

    ; ���нӿ�оƬ 8255
    ; 8255��led�����led״̬
    port55_a    equ 0ffd8H
    port55_ctrl equ 0ffdBH

    ; ������ʱоƬ 8253
    port53_0    equ 0ffe0H
    port53_ctrl equ 0ffe3H      ; ���ƿ�
    count53_second1  equ 19200       ; 1s�������� T7=19.2KHz Tn=4.9152MHz/2^n
    count53_second2  equ 38400       ; 2s��������


    ledbuf                  db 6 dup(?)
    led_count               db 0
    previous_key            db 20h
    current_key             db 20h
    has_previous_bracket    db 0
    has_right_bracket       db 0
    same_as_pre             db 0

    operator_stack          db '#', 100 dup(?)      ; si
    operand_stack           db 0ffh, 0ffh, 100 dup(?)   ; di

    priority                db 0    ; 0 ջ��<��һ��; 1 =; 2 >
    is_save_num             db 0    ; ������һ�������ʱ��current_num�Ƿ��Ѿ����棬Ϊ�˴�������������ŵĴ������
    current_num             dw 0
    display_num             dw 0    ; ���·��ź󣬻��current_num���㣬������display_num����
    has_input_e             db 0    ; ͳ���Ƿ��Ѿ����¹�e��
    result                  dw 0    ; �ܵļ�����
    overflow                db 0
    whole_error             db 0
    
    ; # ( +- *    ���ȼ���С����

    ;   # ( + - *
    ; # f 0 0 0 0
    ; ( f f 0 0 0
    ; + 2 2 1 1 0
    ; - 2 2 1 1 0
    ; * 2 2 2 2 1
    priority_table  db  0ffh, 0, 0, 0, 0
                    db  0ffh, 0ffh, 0, 0, 0
                    db  2, 2, 1, 1, 0
                    db  2, 2, 1, 1, 0
                    db  2, 2, 2, 2, 1


    OUTSEG  equ  0ffdch             ;�ο��ƿ�
    OUTBIT  equ  0ffddh             ;λ���ƿ�/��ɨ��
    IN_KEY  equ  0ffdeh             ;���̶����

    LightOnGreen EQU 0edh ;�̵�  1110 1101   ������Ŀ�����и��Ľ��߷�ʽ����
    LightOnRed EQU 0feh ;���    1111 1110   
    lightOff EQU 0FFH; �ص�      1111 1111
    flag    db 0                ;���Ƿ�����


true_start:
        cli
        call init_all
main:
        call get_key
        cmp current_key, 20h
        je handle
        and  al,0fh
    handle:
        call handle_key
        ;call set_led_num
        call disp
        jmp main
; end



init_all proc
        call init8259
        call init8255
        call init8253
        call initVector
        call clean_all
        ret
init_all endp


init8259 proc
        push ax
        push dx
        mov dx, port59_0
        mov al, icw1
        out dx, al
        mov dx, port59_1
        mov al, icw2
        mov dx, port59_1
        out dx, al
        mov al, icw4
        out dx, al
        mov al, ocw1open
        out dx, al
        pop dx
        pop ax
        ret
init8259 endp


init8255 proc
        push ax
        push dx
        mov dx, port55_ctrl
        mov al, 88H             ;8255A������88H��ʹAB�˿ھ�Ϊ����ڣ�C�ڸ�λ���룬��λ�������ȫ�������ڷ�ʽ0��
        out dx, al
        mov al, lightOff
        mov dx, port55_a
        out dx, al
        pop dx
        pop ax
        ret
init8255 endp


init8253 proc
        push dx
        push ax
        mov dx, port53_ctrl
        mov al, 36H            ; ������0���ȵ�8λ���ٸ�8λ����ʽ3�������Ƽ���
        out dx, al
        pop ax
        pop dx
        ret
init8253 endp


init_stack proc
        mov si, 0
        mov di, 0
        ret
init_stack endp


initVector proc
        cli
        Push bx
        Push ax

        Mov ax , offset flash	;�ж�������ĳ�ʼ��
        Mov bx , vectorOffset
        Mov [bx] , ax

        mov bx,vectorSeg		;�ж������Ķε�ַ��Ӧ���ж�������ĵ�ַ
        mov ax,0000H
        mov [bx],ax

        Pop ax
        Pop bx
        sti
        Ret
initVector endp


clean_all proc
        cli
        call init_stack
        call clean_led
        call ProcTurnOff
        mov previous_key, 20h
        mov current_key, 20h
        mov led_count, 0
        mov has_previous_bracket, 0
        mov has_right_bracket, 0
        mov same_as_pre, 0
        mov current_num, 0
        mov display_num, 0
        mov result, 0
        mov overflow, 0
        mov is_save_num, 0
        mov whole_error, 0
        mov has_input_e, 0
        ret
clean_all endp


clean_led proc
        mov  LedBuf+0,0ffh
        mov  LedBuf+1,0ffh
        mov  LedBuf+2,0ffh
        mov  LedBuf+3,0c0h
        mov  LedBuf+4,0ffh
        mov  LedBuf+5,0ffh
        ret
clean_led endp


;---------------�жϷ������---------------------
flash proc
        cli	;���ж�
        test flag,1	;�жϵ�ǰ���Ƿ���
        Jz turnOn		;�����򿪵�
        ;TurnOff
        call ProcTurnOff	;���������
        Jmp flashOK
    turnOn:
        call ProcTurnOn

    flashOK:
        ; call ProcWriteCount;���¼���
        mov dx,port59_0
        mov al,20h	;0010 0000 ��ͨEOI��ʽ OCW2
        out dx,al
        STI		;���ж�
        IRET
flash endp


ProcTurnOn proc
        push dx
        push ax

        Mov dx, Port55_A
        test result,1h		;�ж��Ƿ�������
        jz green		;��ż�������̵�
        mov al, LightOnRed
        jmp rgOk
    green:
        mov al, LightOnGreen
    rgOk:
        Out dx, al
        mov flag,1

        pop ax
        pop dx

        ret
ProcTurnOn endp

ProcTurnOff proc
        push dx
        push ax
		
        Mov dx, Port55_A
        Mov al, lightOff
        Out dx, al
        mov flag,0

        pop ax
        pop dx

        ret
ProcTurnOff endp


ProcWriteCount proc
        mov dx, port53_0  ;��һ��������ͨ���Ķ˿ڵ�ַ
        test result,1h       ;�ж�result�Ƿ�Ϊ����
        jz second2
        mov ax,count53_second1	;�������������д�������ֵ1s
        jmp countSetOK
    second2:
        mov ax,count53_second2
    countSetOK:
        out dx,al		;��д��8λ���ٶ�д�߰�λ����ʽ3�������Ƽ���
        mov al,ah
        out dx,al
        ret
ProcWriteCount endp


get_key proc                    ;��ɨ�ӳ���
    ; store key in current_key
        push ax
        push bx
        push cx
        push dx

        mov al, current_key     ;��һ��ɨ��ķ���
        mov previous_key, al

        mov  al,0ffh            ;����ʾ��
        mov  dx,OUTSEG
        out  dx,al
        mov  bl,0
        mov  ah,0feh
        mov  cx,8
    key1:   
        mov  al,ah
        mov  dx,OUTBIT
        out  dx,al
        shl  al,1
        mov  ah,al
        nop
        nop
        nop
        nop
        nop
        nop
        mov  dx,IN_KEY
        in   al,dx
        not  al
        nop
        nop
        and  al,0fh
        jnz  key2
        inc  bl
        loop key1
    nkey:   
        mov  al,20h
        mov current_key, al
        pop dx
        pop cx
        pop bx
        pop ax
        ret
    key2:   
        test al,1
        je   key3
        mov  al,0
        jmp  key6
    key3:   
        test al,2
        je   key4
        mov  al,8
        jmp  key6
    key4:   
        test al,4
        je   key5
        mov  al,10h
        jmp  key6
    key5:   
        test al,8
        je   nkey
        mov  al,18h
    key6:   
        add  al,bl
        cmp  al,10h
        jnc  fkey
        mov  bx,offset KeyTable
        xlat
    fkey:   
        mov current_key, al
        pop dx
        pop cx
        pop bx
        pop ax
        ret
get_key endp


handle_key proc
        push ax
        call is_same_as_pre
        cmp same_as_pre, 1
        jne handle_key_continue
        pop ax
        ret
    handle_key_continue:
        mov al, current_key
        cmp al, 10
        jnb handle_key_a
        call handle_number
        pop ax
        ret
    handle_key_a:
        cmp al, 0ah
        jne handle_key_b
        call handle_a
        pop ax
        ret
    handle_key_b:
        cmp al, 0bh
        jne handle_key_c
        call handle_b
        pop ax
        ret
    handle_key_c:
        cmp al, 0ch
        jne handle_key_d
        call handle_c
        pop ax
        ret
    handle_key_d:
        cmp al, 0dh
        jne handle_key_e
        call handle_d
        pop ax
        ret
    handle_key_e:
        cmp al, 0eh
        jne handle_key_f
        call handle_e
        pop ax
        ret
    handle_key_f:
        cmp al, 0fh
        jne key_error
        call handle_f
        jmp handle_key_f_ret
        key_error:
        call handle_error
        handle_key_f_ret:
        pop ax
        ret
handle_key endp

is_same_as_pre proc
    ;��same_as_pre��ֵ
        push ax
        mov al, current_key
        cmp al, previous_key
        je is_same
        mov same_as_pre, 0
        jmp return
    is_same: 
        mov same_as_pre, 1
    return:    
        pop ax
        ret
is_same_as_pre endp



handle_number proc
    ; ��� led_count < 4
    ;   current_num = current_num * 10 + current_key
    ;   led_count += 1
    ; ��������������ķ��ŵ�ʱ����Ҫ��led_count���
        push ax
        push bx
        push dx
        mov is_save_num, 0           ; �����µ�����ʱ�����óɵ�ǰ���ֻ�δ����
        cmp led_count, 4
        jae handle_number_ret
        mov ax, current_num
        mov bx, 10
        mul bx
        mov bl, current_key
        mov bh, 0
        add ax, bx               
        mov current_num, ax          ;current_num = current_num * 10 + current_key
        inc led_count
        push ax
        mov ax, current_num
        mov display_num, ax
        pop ax
        call set_led_num
    handle_number_ret:
        pop dx
        pop bx
        pop ax
        ret
handle_number endp

handle_error proc
    ;����get_key�õ����ַ��������ֺͷ��ŵ����������current_key=20h
        cmp current_key, 20h
        je handle_error_ret
        ; ���������ķ���
    handle_error_ret:
        ret
handle_error endp

handle_a proc
    ; ����������ǼӼ��˵����

    ; ��������Ѿ������������������
    ;   �򲻰�����ѹ��ջ
    ; ����������ջ

    ; Ȼ�����

        cmp is_save_num, 0
        jne calculate_a
        mov is_save_num, 1

        ; ������ջ
        cmp has_right_bracket, 1
        je number_not_push
        inc di
        inc di
        push ax
        mov ax, current_num
        mov operand_stack[di], ah           ;��current_num��ջ
        mov operand_stack[di + 1], al
        pop ax
        jmp next_a
    
    number_not_push:
        mov has_right_bracket, 0
    
    next_a:
        mov led_count, 0
        mov current_num, 0                  ;���������ʱ�������������������ǰ���������
    calculate_a:
        cmp whole_error, 1
        je a_ret                            ;��ǰ���ʽ���Ѿ���������ʱ������ʽ�Ӳ���Ҫ������
        call get_priority
        cmp priority, 0
        je push_a                           ;��ǰ�������ȼ�����ջ�����ţ�ֱ����ջ
        call cal_one_op                     ;�������һ��
        jmp calculate_a
    push_a:
        inc si
        push ax
        mov al, current_key
        mov operator_stack[si], al          ;����ǰ�������ջ
        pop ax
    a_ret:
        ret
handle_a endp

handle_b proc
        call handle_a
        ret
handle_b endp

handle_c proc
        call handle_a
        ret
handle_c endp

handle_d proc
        ;����������������ŵ����
        ;�����������ţ�ֱ����ջ
        ;�����������ţ���������ֱ��ջ����������
        cmp has_previous_bracket, 0
        je no_previous
        mov has_previous_bracket, 0
        mov has_right_bracket, 1

        inc di
        inc di
        push ax
        mov ax, current_num
        mov operand_stack[di], ah          ;��current_num��ջ
        mov operand_stack[di + 1], al
        pop ax
        mov led_count, 0
        mov current_num, 0                    ;���������ʱ�������������������ǰ���������

    cal_between_bracket:
        cmp operator_stack[si], 0dh
        je is_left_bracket
        call cal_one_op
        jmp cal_between_bracket
    is_left_bracket:
        dec si
        jmp ret_d

    no_previous:
        mov has_previous_bracket, 1
        inc si
        push ax
        mov al, current_key
        mov operator_stack[si], al
        pop ax
    ret_d:
        ret
handle_d endp

handle_e proc
        ;�������������'='�����
        ;��һ�ΰ���'='ʱ����������ֱ��ջ����'#'��
        push ax

        cmp has_input_e, 0                ;Ϊ�˽�����µڶ���'e'������ʾ�ڶ��������������⣬�ж��Ѿ������'e'���ٴ�����'e'ʱ�������κβ���
        jne handle_e_ret
        mov has_input_e, 1

        cmp has_right_bracket,1
        je num_not_push_e
        inc di
        inc di
        push ax
        mov ax, current_num
        mov operand_stack[di], ah         ;��current_num��ջ
        mov operand_stack[di + 1], al
        pop ax
    num_not_push_e:
        mov has_right_bracket, 0

    cal_e:
        cmp whole_error, 1
        je ret_e
        cmp operator_stack[si], '#'
        je ret_e
        call cal_one_op
        jmp cal_e
    ret_e:
        cmp whole_error, 1
        je show_error
        cmp di, 2
        ja show_error                    ;������ɺ������ջ��ʣ�����ִ���һ��ʱ����������
        mov ah, operand_stack[di]
        mov al, operand_stack[di + 1]
        mov display_num, ax
        mov result, ax

        call set_led_num
        sti
        call ProcTurnOn
        call ProcWriteCount
        jmp handle_e_ret
    show_error:
        mov  LedBuf+0,0ffh               ;������ִ���ʱ�����ʾ'F'
        mov  LedBuf+1,0ffh
        mov  LedBuf+2,0ffh
        mov  LedBuf+3,8eh
    handle_e_ret:
        pop ax
        ret
handle_e endp

handle_f proc
        ;������'F'�����
        call clean_all
        ret
handle_f endp


cal_one_op proc
        push ax
        push bx
        push dx
        cmp si, 1
        jb cal_error
        cmp di, 4
        jb cal_error
        mov ah, operand_stack[di - 2]
        mov al, operand_stack[di - 1]
        mov bh, operand_stack[di]
        mov bl, operand_stack[di + 1]
        mov dl, operator_stack[si]

        cmp dl, 0ah                 ; +
        jne cal_not_plus
        add ax, bx
        cmp ax,9999
        ja cal_overflow
        jmp cal_ret
    cal_not_plus:
        cmp dl, 0bh                 ; -
        jne cal_not_minus
        cmp ax,bx
        jb cal_overflow         ; �����ø�ҲΪoverflow
        sub ax, bx
        jmp cal_ret
    cal_not_minus:
        cmp dl, 0ch                 ; *
        jne cal_error               ; ���� + - * Ϊerror
        mul bx
        cmp dx, 0
        ja cal_overflow            ; �˷����Ϊoverflow
        cmp ax,9999
        ja cal_overflow
        jmp cal_ret
    cal_error:
        mov whole_error, 1
        jmp cal_ret
    cal_overflow:
        mov overflow, 1
    cal_ret:
        dec di
        dec di
        dec si
        mov operand_stack[di], ah
        mov operand_stack[di + 1], al
        pop dx
        pop bx
        pop ax
        ret
cal_one_op endp


get_priority proc
        push ax
        push bx
        push dx
        mov al, operator_stack[si]
        cmp al, '#'
        jne top_not_pound
        mov al, 0
        jmp curr_operator
        top_not_pound:
        cmp al, 0dh
        jne top_not_bracket
        mov al, 1
        jmp curr_operator
        top_not_bracket:
        sub al, 0ah
        add al, 2

        curr_operator:
        mov dl, current_key
        cmp dl, 0dh
        jne curr_operator_not_pound
        mov dl, 1
        jmp find_in_table
        curr_operator_not_pound:
        sub dl, 0ah
        add dl, 2

        find_in_table:
        mov dh, 5           ; 5 x 5 �����ȱ�
        mul dh
        add al, dl
        mov ah, 0
        mov bx, ax
        mov dl, priority_table[bx]
        mov priority, dl
        jmp get_priority_ret
    get_priority_err:
        mov whole_error, 1
    get_priority_ret:
        pop dx
        pop bx
        pop ax
        ret
get_priority endp


set_led_num proc
    ; ��handle_number�����ʱ
    ; ��ʱled_count = �����������λ��
    ; led_count - 1 = ����ʾ������λ��
        push ax
        push bx
        push cx
        push dx
        push di
        mov  LedBuf+0,0ffh
        mov  LedBuf+1,0ffh
        mov  LedBuf+2,0ffh
        mov  LedBuf+3,0ffh
        mov di, 3
        mov ax, display_num
        
        cmp overflow, 1
        jne ax_not_zero
        
        overFshow:
        mov LedBuf+3,08eh       ; 8eh : 'F'
        JMP set_led_num_ret

    ax_not_zero:

        mov bx, offset ledmap
        mov dx, 0               ; dx Ϊ�������ĸ�λ����Ҫ��Ϊ0
        mov cx, 10              ; cx ������
        div cx
        add bx, dx              ; �����dxΪ������axΪ�̣��������ӵ�ledmap��ƫ�Ƶ�ַ��
        mov dl, [bx]            ; bxΪ����ĵ�ַ��dl ����Ҫ��ʾ�Ķ���

        mov bx, offset ledbuf   
        add bx, di
        mov [bx], dl            ; �ȼ��� mov ledbuf+di, dl
        dec di
        
        cmp ax, 0
        jne ax_not_zero

    set_led_num_ret:
        pop di
        pop dx
        pop cx
        pop bx
        pop ax
        ret
set_led_num endp



disp proc
        mov  bx,offset LEDBuf
        mov  cl,6               ;��6���˶ι�
        mov  ah,00100000b       ;����߿�ʼ��ʾ
    DLoop:
        mov  dx,OUTBIT
        mov  al,0
        out  dx,al              ;�����а˶ι�
        mov  al,[bx]
        mov  dx,OUTSEG
        out  dx,al

        mov  dx,OUTBIT
        mov  al,ah
        out  dx,al              ;��ʾһλ�˶ι�

        push ax
        mov  ah,1
        call Delay
        pop  ax

        shr  ah,1
        inc  bx
        dec  cl
        jnz  DLoop

        mov  dx,OUTBIT
        mov  al,0
        out  dx,al              ;�����а˶ι�
        ret
disp endp

delay proc                         ;��ʱ�ӳ���
        push  cx
        mov   cx,256
        loop  $
        pop   cx
        ret
delay endp

    ;�˶ι���ʾ��
    LedMap  db   0c0h,0f9h,0a4h,0b0h,099h,092h,082h,0f8h
            db   080h,090h,088h,083h,0c6h,0a1h,086h,08eh
    ;���붨��
    KeyTable db   07h,04h,08h,05h,09h,06h,0ah,0bh
            db   01h,00h,02h,0fh,03h,0eh,0ch,0dh

code    ends
        end start
