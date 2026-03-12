---
screenId: login
title: Login
platforms: [ios, android, html]
intent: quiet single-column login
constraints:
  - one dominant primary action
  - no decorative elements
  - semantic tokens only
states:
  - default
  - loading
  - error
components:
  - text.title
  - text.body
  - textField.email
  - secureField.password
  - button.primary
  - text.caption
---
Use one title, two fields, and one primary action.
The screen should feel calm, direct, and minimal.
Errors should be short and explicit.

## State Fields
- email | type=string | default=""
- password | type=string | default=""

## Actions
- submitLogin

## Preview States
- default | values={"email":"","password":""}
- loading | values={"email":"alex@example.com","password":"hunter2"} | note=Submitting credentials
- error | values={"email":"alex@example.com","password":""} | note=Invalid email or password.

## Component Details
- text.title | text=Welcome back
- text.body | text=Use your account to continue.
- textField.email | id=emailField | label=Email | binding=email
- secureField.password | id=passwordField | label=Password | binding=password
- button.primary | title=Continue | action=submitLogin
- text.caption | text=No extra decoration. Just the essentials.
