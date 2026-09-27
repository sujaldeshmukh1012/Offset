# Opportunity Image Replacement Prompts

Generate each asset at a 3:2 landscape aspect ratio, ideally 1400×933 pixels or larger, then export as an sRGB JPEG using the exact filename shown. Keep a copy of the original generated output and its generation record before resizing or compression.

## Shared art direction

Apply this direction to every prompt:

> Premium editorial architectural photography for a trustworthy US home-energy savings app. Photorealistic but natural rather than glossy advertising, contemporary middle-class American home, warm daylight, neutral whites, soft gray, restrained deep blue and natural green accents, realistic materials and physically plausible installation, clean composition readable as a small mobile card, main subject in the central safe area, no people, no readable text, no logos, no trademarks, no brand-specific product design, no license-plate characters, no watermark, no border, no UI elements, no exaggerated environmental symbolism, no duplicated or malformed equipment.

## `OpportunityEV.jpg`

> A generic modern electric crossover parked in the driveway of a tidy suburban American home, viewed from a rear three-quarter angle. The charging port is visibly and correctly connected by one realistic cable to a compact wall-mounted Level 2 home charger beside the garage. The vehicle and charger are completely unbranded. Late-afternoon natural light, tasteful landscaping, believable scale and cable routing, EV and charger are immediately recognizable, ample uncluttered space around the subject. 3:2 landscape architectural lifestyle photograph. Apply the shared art direction.

## `OpportunityHeatPump.jpg`

> A modern unbranded cold-climate air-source heat-pump outdoor unit installed beside a well-maintained suburban American house. Show one correctly proportioned condenser on a level concrete pad with realistic wall clearance, insulated line set, electrical disconnect and conduit, neat drainage and landscaping that does not block airflow. Three-quarter eye-level view, soft morning light, the equipment is the unmistakable focal point. 3:2 landscape architectural photograph. Apply the shared art direction.

## `OpportunitySolar.jpg`

> A welcoming contemporary American detached home with a clearly visible, professionally installed rooftop solar photovoltaic array. Panels follow the roof plane in a clean rectangular layout with realistic mounting, spacing, perspective and reflections; no impossible roof geometry, loose wiring or branded hardware. Front three-quarter exterior view in warm late-afternoon sunlight, blue sky with subtle natural clouds, understated landscaping, solar panels remain visually dominant at mobile-card size. 3:2 landscape architectural photograph. Apply the shared art direction.

## `OpportunityWeatherization.jpg`

> The interior of a clean residential attic during a completed professional weatherization upgrade. Symmetrical timber roof framing and a deep, even layer of new light-colored blown-in insulation across the attic floor, with joist paths and ventilation baffles remaining physically plausible and an unobstructed small window admitting warm daylight. No exposed unsafe wiring, no workers, tools, packaging or debris. The insulation improvement is obvious at a glance. 3:2 landscape documentary architectural photograph. Apply the shared art direction.

## `OpportunityWindows.jpg`

> A bright, comfortable contemporary living room centered on newly installed high-performance replacement windows. Large unbranded double-pane or triple-pane windows have realistic frames, glass thickness, reflections and outdoor perspective; subtle hardware and clean professional trim make energy-efficient windows the clear subject. Warm natural sunlight, neutral furnishings, restrained blue accents, no people and no staged signage. 3:2 landscape interior architectural photograph. Apply the shared art direction.

## Replacement and provenance steps

1. Generate each image separately; do not ask a generator for a five-image collage.
2. Reject outputs containing logos, text, recognizable people, malformed equipment, unsafe installations, or impossible construction details.
3. Crop/export each approved image to exactly 1400×933 pixels as an sRGB JPEG.
4. Replace the existing JPEG inside its matching `.imageset` directory without changing the filename or `Contents.json`.
5. Record the generator, generation date, prompt/job ID, commercial-use terms, and any edits in `ASSET_PROVENANCE.md`.
6. Build the app and inspect every opportunity card on iPhone and iPad before submission.
