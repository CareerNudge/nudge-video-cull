# Nudge Video Cull - Feature Update: Enriched Professional Metadata

## 1. Project Goal

The primary goal of this task is to enhance the application's metadata capabilities by parsing data from Sony's `.XML` "sidecar" files. When a video file has a corresponding `.XML` file, the app must read this "enriched" data and display it in a **new, second metadata column** in the UI.

This will provide users with professional, camera-native information (like Lens, Gamma, and Timecode) that is not available from the video file alone.

---

## 2. The .XML Sidecar File

Many professional cameras, like the user-provided Sony example, do not write all metadata to the video file itself. Instead, they write an `.XML` sidecar file with the **exact same base filename**.

**File Naming Convention:**
* **Video File:** `C0001.MP4`
* **Sidecar File:** `C0001.XML`

Your task is to implement a system that, upon finding a video file, immediately looks for its accompanying `.XML` "buddy" file.

### Sample XML (`20250802_A7C_7378M01.XML`)

The agent must be able to parse an XML structure similar to the following:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NonRealTimeMeta xmlns="urn:schemas-professionalDisc:nonRealTimeMeta:ver.2.20" ...>
	
    <Duration value="372"/>
	
    <LtcChangeTable tcFps="24" halfStep="false">
		<LtcChange frameCount="0" value="16162602" status="increment"/>
	</LtcChangeTable>
	
    <CreationDate value="2025-08-02T08:32:59-04:00"/>
	
    <VideoFormat>
		<VideoFrame videoCodec="HEVC_3840_2160_M42210P@L5HT" captureFps="23.98p" formatFps="23.98p"/>
		<VideoLayout pixel="3840" numOfVerticalLine="2160" aspectRatio="16:9"/>
	</VideoFormat>
	
    <AudioFormat numOfChannel="2">
		<AudioRecPort audioCodec="LPCM16" trackDst="CH1"/>
	</AudioFormat>
	
    <Device manufacturer="Sony" modelName="ILCE-7CM2"/>
	
    <Lens modelName="50mm F2 DG DN | Contemporary 02"/>
	
    <AcquisitionRecord>
		<Group name="CameraUnitMetadataSet">
			<Item name="CaptureGammaEquation" value="rec709"/>
			<Item name="CaptureColorPrimaries" value="rec709"/>
		</Group>
        <ChangeTable name="Gyroscope">
			<Event frameCount="0" status="start"/>
		</ChangeTable>
		<ChangeTable name="Accelerometor">
			<Event frameCount="0" status="start"/>
		</ChangeTable>
	</AcquisitionRecord>
</NonRealTimeMeta>