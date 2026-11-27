# kaist-openconnect

**한국어** | [English](README.en.md)

브라우저 없이 터미널에서 바로 **KAIST VPN**(Ivanti Connect Secure + AirCUVE
"2Auth" 2단계 인증)에 접속하는, 의존성 없는 작은 명령줄 클라이언트입니다.

ID, 비밀번호, 일회용 코드(SMS 또는 이메일)를 입력받아 2단계 인증을 완료한 뒤
[OpenConnect](https://www.infradead.org/openconnect/)로 터널을 엽니다.

## 설치

터미널에 아래 한 줄을 붙여넣으면 끝입니다 — Homebrew(macOS, 없을 때만)와
OpenConnect까지 필요한 것을 전부 설치하고, `kvpn`을 `PATH`에 연결합니다:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/predict-woo/kaist-openconnect/main/install.sh)"
```

설치가 끝나면 `kvpn`으로 실행하세요. 이미 설치된 것은 건너뛰므로 다시 실행해도
안전하며, 다시 실행하면 kvpn이 최신 버전으로 갱신됩니다. Linux에서는 배포판
패키지 관리자(apt/dnf/pacman/zypper)로 의존성을 설치합니다.

<details>
<summary>수동 설치 (설치 스크립트를 쓰고 싶지 않다면)</summary>

[요구 사항](#요구-사항)을 직접 설치한 뒤:

```sh
git clone https://github.com/predict-woo/kaist-openconnect.git
cd kaist-openconnect
chmod +x kvpn
./kvpn
```

원한다면 `PATH`에 추가하세요:

```sh
ln -s "$PWD/kvpn" /usr/local/bin/kvpn
```

</details>

기본 ID를 설정해 두면 프롬프트에서 Enter만 누르면 됩니다:

```sh
export KVPN_USER=your_id   # ~/.zshrc 또는 ~/.bashrc 에 추가
```

![kvpn 전체 세션: ID/비밀번호/realm 입력, SMS 일회용 코드, 키체인 저장 여부 확인, OpenConnect 터널 연결](docs/screenshot.png)

자격 증명을 저장해 두면 이후 실행에서는 곧바로 코드 인증 단계로 넘어갑니다.
macOS에서는 다음과 같이 SMS 코드를 자동으로 기다립니다:

```
$ ./kvpn
=== KAIST VPN (kvpn) ===
Using stored credentials for your_id (KAIST Members). Run `kvpn --forget` to remove.
Code sent via SMS. It may take up to a minute to arrive.
Waiting up to 60 seconds for a KVPN SMS in Messages...
```

## 왜 만들었나

KAIST VPN은 Ivanti Connect Secure에 AirCUVE 2차 인증을 얹은 구조인데, OTP 단계가
별도 호스트의 JavaScript 포털 안에서 동작합니다. OpenConnect 단독으로는 이 포털을
처리할 수 없어서, 흔한 해법은 "브라우저로 로그인해서 `DSID` 쿠키를 복사한 다음
openconnect를 실행하라"는 것이었습니다. 이 도구는 그 과정 전체를 자동화합니다:
포털의 OTP 흐름을 순수 HTTP로 수행하고, 얻은 세션 쿠키를 OpenConnect에
넘겨줍니다.

**아무것도 우회하지 않습니다.** 공식 클라이언트와 똑같이, 매 접속마다 본인의
비밀번호와 새 일회용 코드로 인증합니다.

## 요구 사항

- **Python 3** (표준 라이브러리만 사용 — `pip install` 불필요)
- **[OpenConnect](https://www.infradead.org/openconnect/)** — `PATH`에 있어야
  합니다 (macOS에서는 `brew install openconnect`)
- `sudo` 권한 (OpenConnect가 터널 인터페이스를 만들려면 root가 필요합니다)

macOS에서 개발·테스트했습니다. Linux에서도 OpenConnect 기본 `vpnc-script`로
동작할 것으로 예상합니다; 제보 환영합니다.

## 사용법

`./kvpn`을 실행하고 프롬프트를 따라가면 됩니다. 연결을 끊으려면 실행 중인
터미널에서 **Ctrl-C** 를 누르세요 — OpenConnect가 터널을 정리하고 라우팅을
복원합니다.

### macOS: SMS 코드 자동 입력

```sh
kvpn
```

macOS에서는 기본으로 SMS 전송을 선택한 뒤, Mac의 메시지 앱에 도착한 새 KVPN
인증 문자를 최대 60초 동안 자동으로 기다려 코드를 입력합니다. 메시지에 접근할
권한이 없으면 권한 설정 방법을 안내하고, 별도 옵션 없이 수동 코드 입력으로
자동 전환합니다. 60초 안에 코드를 찾지 못한 경우에도 수동 입력으로 전환합니다.

수동으로 입력하거나 이메일 인증을 사용하려면 다음과 같이 실행하세요. 이때는
메시지 데이터베이스에 접근하지 않습니다.

```sh
kvpn --no-auto-sms
```

`--auto-sms`로 자동 입력을 명시할 수도 있습니다.

준비 사항:

1. iPhone의 인증 SMS가 Mac 메시지 앱에도 표시되어야 합니다. 같은 Apple 계정을
   사용하고 [문자 메시지 전달](https://support.apple.com/102545)을 설정하세요.
2. **시스템 설정 → 개인정보 보호 및 보안 → 전체 디스크 접근 권한**에서 kvpn을
   실행하는 앱(예: Terminal, iTerm2, Emacs)의 접근을 허용하세요. 권한 변경 후
   해당 앱을 완전히 종료하고 다시 실행해야 할 수 있습니다.

Linux에서는 기존 SMS/이메일 선택과 수동 코드 입력을 사용합니다.
기다리는 동안 `Ctrl-C`를 누르면 연결 시도를 취소합니다.

### macOS: sudo Touch ID 인증 (선택)

Touch ID를 지원하는 Mac은 sudo의 PAM 설정으로 지문 인증을 사용할 수 있습니다.
`kvpn`은 시스템 sudo 인증을 그대로 사용하며 지문이나 Mac 비밀번호를 저장하지
않습니다. 이 설정은 kvpn 외의 sudo 명령에도 적용됩니다.

최근 macOS에서는 `/etc/pam.d/sudo`에 `sudo_local` 포함 설정이 있는지 확인한 뒤,
시스템의 `/etc/pam.d/sudo_local.template` 안내에 따라
`/etc/pam.d/sudo_local`에 다음 항목을 설정할 수 있습니다. 기존 설정을 유지하고,
`/etc/pam.d/sudo` 자체는 수정하지 않아도 됩니다.

```text
auth       sufficient     pam_tid.so
```

관리자 권한이 필요하며, `sudo -k` 후 `sudo -v`로 인증을 확인할 수 있습니다.
Touch ID 사용 가능 여부는 실행 환경에 따라 달라지며 비밀번호 인증이 필요할
수도 있습니다. kvpn은 이 시스템 설정을 자동으로 변경하지 않습니다.

### 자격 증명 저장

로그인에 성공하면 kvpn이 자격 증명 저장을 제안하며, 저장해 두면 이후 실행은
곧바로 코드 인증 단계로 넘어갑니다. 비밀번호는 **macOS 키체인**(서비스명
`kvpn`)에, ID와 realm은 `~/.config/kvpn/config.json`(사용자 전용, `0600`)에
저장됩니다. 키체인이 없는 시스템에서는 비밀번호도 같은 `0600` 파일에 저장됩니다
(저장 전에 경고를 띄웁니다). 어느 경우든 일회용 코드는 매 접속마다 새로
필요합니다.

저장된 내용을 모두 삭제하려면:

```sh
./kvpn --forget
```

`KVPN_DEBUG=1`을 설정하면 내부 HTTP 리다이렉트 체인을 출력합니다(로그인 흐름이
바뀌어 뭔가 깨졌을 때 유용합니다):

```sh
KVPN_DEBUG=1 ./kvpn
```

## 참고 및 문제 해결

- **자격 증명 저장은 선택(opt-in)입니다.** 저장 프롬프트에서 "y"라고 답하지 않는
  한 아무것도 저장되지 않으며, `kvpn --forget`으로 전부 삭제할 수 있습니다.
  `DSID`는 어차피 일시적이고(연결이 끊기면 소멸), 일회용 코드는 매 접속마다 새로
  필요합니다.
- **저장된 비밀번호가 낡았다면?** KAIST 비밀번호를 바꾸면 마지막 로그인 단계가
  실패합니다 — `kvpn --forget` 후 다시 로그인하세요.
- **`sudo` 프롬프트 충돌:** stdin이 파이프로 연결된 탓에 `sudo`가 오작동하면
  `sudo -v`를 먼저 실행한 뒤 `./kvpn`을 실행하세요.
- **무해한 라우트 경고:** 접속 시 자기 VPN IP로의 라우트나 이미 존재하는 라우트에
  대해 `Can't assign requested address` / `File exists` 같은 줄이 보일 수
  있습니다. 나머지 라우트는 모두 정상적으로 설치되며 연결에는 영향이 없습니다.
- **로그인이 갑자기 깨졌다면** KAIST가 포털 흐름을 바꿨을 가능성이 큽니다.
  `KVPN_DEBUG=1`로 실행해 (민감한 정보를 가린) hop 목록과 함께 이슈를 올려주세요.

## 면책 조항

이 도구는 비공식 개인 상호운용성(interoperability) 도구이며, **KAIST, Ivanti,
AirCUVE와 무관하고 이들의 승인을 받지 않았습니다**. 본인 계정으로, 소속 기관의
이용 정책에 맞게 사용하세요. 어떤 종류의 보증도 없이 "있는 그대로" 제공됩니다
([LICENSE](LICENSE) 참조).

## 감사의 말

실제 VPN 터널링을 담당하는 훌륭한
[OpenConnect](https://www.infradead.org/openconnect/) 프로젝트 위에
만들어졌습니다.
