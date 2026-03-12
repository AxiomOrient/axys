---
screenId: product-detail
title: Product Detail
route: /products/studio-chair
platforms: [ios, android, html]
intent: focused product summary with one purchase action
constraints:
  - one clear information hierarchy
  - one primary CTA
  - semantic tokens only
states:
  - default
components:
  - image.hero
  - text.title
  - text.body
  - card
  - button.primary
  - button.secondary
---
Present the product image, name, short summary, price context, and one purchase action.
The screen should remain quiet and compact.

## Actions
- addToCart

## Preview States
- default | note=Default purchase review state.

## Assets
- studio-chair.png | kind=image

## Navigation
- shippingDetails | route=/products/studio-chair/shipping

## Component Details
- image.hero | assetName=studio-chair.png
- text.title | text=Studio Chair
- text.body | text=A quiet profile, durable materials, and a compact footprint.
- card | label=Price | body=$240 | caption=Delivery included.
- button.primary | title=Add to cart | action=addToCart
- button.secondary | title=Shipping details | navigation=shippingDetails
