# Chronote "Today's Insight" Testing Checklist

## Test Date: February 5, 2026

### Pre-Testing Setup
- [x] Build succeeded without errors
- [x] All new files created and integrated
- [x] Database schema updated with new models

---

## 1. Navigation Testing

### Sidebar Integration
- [ ] Open the app
- [ ] Verify new "Insights" section appears above "Activities" in sidebar
- [ ] Verify "Today's Insight" item with chart icon is visible
- [ ] Click "Today's Insight" - should navigate to Insight view
- [ ] Click "All Activities" - should return to activity list view
- [ ] Click "Today's Insight" again - should work consistently

**Expected Result**: Smooth navigation between Insight view and Activities view

---

## 2. Insight View - No Data Scenario

### Test when no activities exist for today
- [ ] Select today's date
- [ ] Click "Today's Insight"
- [ ] Verify empty state appears with:
  - Chart icon
  - "No Data Available" message
  - "Start tracking your activities to see insights here." text

**Expected Result**: Clear empty state message, no errors

---

## 3. Insight View - With Activities

### Prerequisites: 
Run the app for a while to generate activities, or use existing data from previous days

### Test with existing activities
- [ ] Click "Today's Insight"
- [ ] Verify loading spinner appears briefly
- [ ] Verify view loads without errors

### Narrative Header Card
- [ ] Verify blue highlighted card appears at top
- [ ] Verify "TODAY'S INSIGHT" label in blue caps
- [ ] Verify headline text is readable and makes sense
- [ ] Verify subtext provides additional context
- [ ] Text should wrap properly, no truncation

**Example Headline**: 
- "Your day was mostly fragmented. Only 2 deep focus sessions occurred, totaling 1h 42m."
- "Today was productive with 3 deep focus sessions totaling 2h 15m."

---

## 4. Time Structure Section

### Stacked Bar Visualization
- [ ] Verify "Time Structure" header with total tracked time
- [ ] Verify horizontal colored bar appears
- [ ] Verify bar is divided into colored segments:
  - **Blue** = Deep work
  - **Orange** = Fragmented
  - **Gray** = Passive
  - **Purple** = Communication
  - **Light Gray** = Idle
- [ ] Verify segments are proportional to durations
- [ ] No gaps or overlaps in bar

### Legend
- [ ] Verify legend appears below bar
- [ ] Each legend item shows:
  - Colored square (12x12px)
  - Type name and percentage
- [ ] Only shows types that have non-zero percentages
- [ ] Percentages add up to ~100%

---

## 5. Behavioral Blocks List

### Block List Display
- [ ] Verify "Behavioral Blocks" header with count (e.g., "12 blocks today")
- [ ] Verify blocks appear in list format
- [ ] Each block shows:
  - Colored vertical bar on left (type indicator)
  - App name (e.g., "VS Code", "Chrome")
  - Duration (e.g., "42m", "1h 15m")
  - Time range (e.g., "10:30 AM - 11:18 AM")
  - Context switches if > 0 (e.g., "5 switches")

### Block Colors Match Types
- [ ] Deep work blocks = Blue bar
- [ ] Fragmented blocks = Orange bar
- [ ] Passive blocks = Gray bar
- [ ] Communication blocks = Purple bar
- [ ] Idle blocks = Light gray bar

### Expand Functionality
- [ ] If more than 4 blocks exist, verify "Show X more blocks" button appears
- [ ] Click expand button
- [ ] Verify all blocks now visible
- [ ] Button should disappear after expansion

---

## 6. Daily Comparison Section

### Prerequisites: 
Need data from yesterday to show comparisons

### Comparison Cards
- [ ] Verify "Compared to Yesterday" header
- [ ] Verify 3 comparison cards appear side by side:
  1. **Deep Focus** (green/red arrow)
  2. **Fragmented Time** (green/red arrow)
  3. **Passive Time** (green/red arrow)

### Each Card Shows
- [ ] Metric name (e.g., "Deep Focus")
- [ ] Today's value (e.g., "1h 42m")
- [ ] Change percentage with arrow icon
- [ ] Correct color coding:
  - Green = good change (more deep work)
  - Red = bad change (more fragmented)
  - Gray = minimal change

---

## 7. Data Analysis Pipeline Testing

### Session Creation
- [ ] Open Activity log and note activity count
- [ ] Click "Today's Insight"
- [ ] Check Console logs for "Created X sessions" message
- [ ] Sessions should group activities within 5-minute gaps

### Behavioral Classification
- [ ] Check Console for "Created X behavioral blocks"
- [ ] Verify classification makes sense:
  - Long VS Code sessions → Deep work
  - Rapid app switching → Fragmented
  - Extended Chrome/Safari → Passive
  - Slack/Mail → Communication

### Time Structure
- [ ] Check Console for time structure breakdown
- [ ] Verify percentages are calculated correctly
- [ ] Total should match sum of all durations

### Insight Generation
- [ ] Headline should reflect dominant pattern
- [ ] Subtext should provide specific detail
- [ ] No placeholder text or "Unknown" values

---

## 8. Error Handling

### No Activities Scenario
- [ ] Select a date with no activities
- [ ] Click "Today's Insight"
- [ ] Verify empty state (not error state)

### Analysis Error Scenario
- [ ] If analysis fails, verify error view shows:
  - Warning icon
  - "Analysis Error" title
  - Error description
  - "Try Again" button
- [ ] Click "Try Again" should re-attempt analysis

---

## 9. Date Range Integration

### Change Date Range
- [ ] Click "Today's Insight"
- [ ] Change date picker to yesterday
- [ ] Verify Insight view updates for yesterday's data
- [ ] Change to different date
- [ ] Verify loading and data refresh

---

## 10. Performance Testing

### Loading Performance
- [ ] First load should complete within 2-3 seconds
- [ ] Subsequent loads should be faster (cached)
- [ ] No UI freezing during analysis
- [ ] Smooth scrolling in Insight view

### Memory
- [ ] Open Activity Monitor
- [ ] Navigate to Insight view multiple times
- [ ] Memory usage should remain stable
- [ ] No memory leaks

---

## 11. Visual Polish

### Spacing & Layout
- [ ] Consistent 24pt spacing between sections
- [ ] 32pt horizontal padding
- [ ] All text is readable
- [ ] No text overflow or truncation
- [ ] Rounded corners on cards (16pt radius)

### Colors
- [ ] Blue accent color matches design
- [ ] Light blue background on narrative card
- [ ] Proper contrast for readability
- [ ] Border colors are subtle (gray 0.2 opacity)

---

## 12. Edge Cases

### Very Short Day (< 2 hours tracked)
- [ ] Verify subtext mentions "Limited tracking data"
- [ ] No crash or error

### Very Long Day (> 12 hours)
- [ ] Time formatting works correctly
- [ ] No overflow in UI
- [ ] Percentages still add to 100%

### No Deep Work All Day
- [ ] Headline reflects this accurately
- [ ] No "undefined" or null values
- [ ] Still shows other categories

### All Idle Time
- [ ] Properly classified as Idle
- [ ] Headline mentions low activity
- [ ] No division by zero errors

---

## 13. Integration with Existing Features

### Activity Tracking Continues
- [ ] Click "Today's Insight"
- [ ] ActivityManager should still track in background
- [ ] Switch to "All Activities" - verify new activities appear

### Project Filtering
- [ ] While in Activities view, select a project
- [ ] Click "Today's Insight"
- [ ] Should show all activities (not filtered by project)

---

## Known Limitations (Expected Behavior)

1. **Timeline View**: Not implemented in MVP - that's okay
2. **First-time analysis**: May take 2-3 seconds
3. **No data prompt**: Expected when no activities exist
4. **Yesterday comparison**: Won't show on first day of usage

---

## Test Results Summary

**Date Tested**: ___________  
**Tester**: ___________  
**Build Version**: Debug  

**Overall Status**: 
- [ ] PASS - All critical features work
- [ ] PASS with minor issues - Works but has cosmetic issues
- [ ] FAIL - Critical functionality broken

**Critical Issues Found**: 
_________________

**Minor Issues Found**: 
_________________

**Notes**: 
_________________
