#!/usr/bin/env python3
"""
Generate 1000+ realistic gym influencer prompts for batch processing
"""
import random
import os

# Create prompts directory
os.makedirs('../prompts', exist_ok=True)

# Prompt components
poses = [
    "gym mirror selfie", "squat pose", "deadlift", "yoga pose", "plank position",
    "lunges", "bicep curl", "running on treadmill", "bench press", "lat pulldown",
    "leg press", "cable crossover", "dumbbell rows", "shoulder press", "burpees",
    "box jumps", "kettlebell swings", "battle ropes", "pull-ups", "push-ups"
]

locations = [
    "gym mirror", "home gym", "outdoor park", "yoga studio", "CrossFit box",
    "hotel gym", "beach workout", "rooftop gym", "garage gym", "fitness center"
]

outfits = [
    "sports bra and leggings", "tank top and shorts", "yoga pants and crop top",
    "athletic wear", "gym outfit", "compression gear", "running shorts",
    "workout dress", "sports bikini", "fitness bodysuit"
]

lighting = [
    "natural lighting", "gym lighting", "golden hour", "studio lighting",
    "soft window light", "dramatic shadows", "bright overhead lights",
    "sunset glow", "morning light", "neon gym lights"
]

details = [
    "detailed abs", "toned arms", "athletic legs", "defined muscles",
    "fit physique", "detailed biceps", "sculpted shoulders", "strong core",
    "muscular thighs", "detailed glutes"
]

skin_details = [
    "detailed skin texture", "natural pores", "sweaty skin", "glowing skin",
    "detailed skin pores", "realistic skin", "detailed face", "natural makeup"
]

camera = [
    "iPhone candid", "iPhone 15 Pro Max photo", "amateur photo", "selfie camera",
    "professional camera", "DSLR quality", "phone camera", "mirror selfie"
]

# NSFW variations (optional)
nsfw_details = [
    "visible cleavage", "tight outfit", "form-fitting clothes", "athletic curves",
    "defined body shape", "fitness physique"
]

# Generate SFW prompts
sfw_prompts = []
base_sfw = "ultra-realistic Instagram fitness model, {pose}, {location}, {outfit}, {detail}, {lighting}, {camera}, {skin}, 8k uhd, detailed hands and face"

for _ in range(700):
    prompt = base_sfw.format(
        pose=random.choice(poses),
        location=random.choice(locations),
        outfit=random.choice(outfits),
        detail=random.choice(details),
        lighting=random.choice(lighting),
        camera=random.choice(camera),
        skin=random.choice(skin_details)
    )
    sfw_prompts.append(prompt)

# Generate NSFW prompts
nsfw_prompts = []
base_nsfw = "ultra-realistic Instagram fitness model, {pose}, {location}, {outfit}, {detail}, {nsfw}, {lighting}, {camera}, {skin}, 8k uhd, detailed anatomy"

for _ in range(300):
    prompt = base_nsfw.format(
        pose=random.choice(poses),
        location=random.choice(locations),
        outfit=random.choice(outfits),
        detail=random.choice(details),
        nsfw=random.choice(nsfw_details),
        lighting=random.choice(lighting),
        camera=random.choice(camera),
        skin=random.choice(skin_details)
    )
    nsfw_prompts.append(prompt)

# Save prompts
with open('../prompts/gym_influencer_sfw.txt', 'w') as f:
    f.write('\n'.join(sfw_prompts))

with open('../prompts/gym_influencer_nsfw.txt', 'w') as f:
    f.write('\n'.join(nsfw_prompts))

with open('../prompts/gym_influencer_all.txt', 'w') as f:
    f.write('\n'.join(sfw_prompts + nsfw_prompts))

print(f"Generated {len(sfw_prompts)} SFW prompts")
print(f"Generated {len(nsfw_prompts)} NSFW prompts")
print(f"Total: {len(sfw_prompts) + len(nsfw_prompts)} prompts")
print("\nFiles created:")
print("- prompts/gym_influencer_sfw.txt")
print("- prompts/gym_influencer_nsfw.txt")
print("- prompts/gym_influencer_all.txt")
