# Spec Generation Prompt

목표: screen-doc를 읽고 ScreenSpec JSON만 출력한다.

규칙:
- JSON 외의 텍스트를 출력하지 않는다.
- component kind는 catalog에 있는 것만 사용한다.
- spacing / surface style은 raw literal이 아니라 token alias를 사용한다.
- 하나의 primary action만 유지한다.
- 장식적 요소를 invent하지 않는다.
- platform-specific field를 넣지 않는다.
