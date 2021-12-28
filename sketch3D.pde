/*
 * References: 
https://discourse.processing.org/t/camera-rotation-in-3d-using-mouse/20563 
https://forum.processing.org/two/discussion/1747/reading-filesnames-from-a-folder 
https://docs.oracle.com/javase/7/docs/api/java/io/File.html
https://processing.org/examples/orthographic.html 
https://www.local-guru.net/blog/2019/1/22/processing-sound-visualizer-explained 
https://www.local-guru.net/ebook/processing-ebook-beta2.pdf
http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.11.9150 
*/
import ddf.minim.*;
import ddf.minim.spi.*;
import ddf.minim.analysis.FFT;
//import processing.pdf.*;
import java.io.File;

Minim minim;
AudioPlayer player;
AudioMetaData meta;
//AudioStream in;
//MultiChannelBuffer sb;

int grid = 100;
PVector bpos = new PVector();
float bsize = grid;
float cameraRotateX;
float cameraRotateY;
float cameraSpeed;
int gridCount = 20;

/* inherited from source
PVector posn, speed;
float bspeedX, bspeedY, bspeedZ;
boolean input1, input2, input3, input4;
float accelMag;
*/

int B;           // player buffer size, typically 1024 (samples/cycle)
int D;           // log2(B)
int N;           // some fraction of buffer size <= 1024 (samples/cycle)
int M;           // log2(N)
float S;         // sample rate = 41000 Hz (samples/second)
float T;         // Nyquist sample rate = 2048/41000 = 0.25 (seconds/cycle) = 1/(2Fc)
float Fc;        // Nyquist frequency = 1/(4T) ~= 10 Hz @ HIGH-RES, otherwise = 1/(2T)

// expects a subfolder called 'samples' containing mp3 or wav files
// defaults to looking in a subfolder called 'data', hence the '..'
String samplePath = "..\\samples";
File sampleFolder; 
String[] samples;
int track = 0;     // current track being loaded / played
int maxTrack = 0;
String[] tracks;
int frameRt = 30;  // # of frames per second to render (24/30)
float zoom = 1.0;
cmWin wd;          // windows for rendered audio/frequency data

boolean PERSPC = false;
boolean BOX_ON = true;
boolean GRD_ON = true;
boolean AUD_ON = false;
boolean LOGSCL = false;

// Global audio data
//FFT fftLib;      // built-in FFT library for error checking
float[] LnR;
float[] Lbuf;
float[] Rbuf;
float[] level;
int pos, len;

void setup()
{
  // bugs in minim when playing files @ 32kHz sample rate
  minim = new Minim(this); 
  sampleFolder = new File(dataPath(samplePath));
  samples = sampleFolder.list(); 
  if (samples != null) {
    maxTrack = samples.length;
  } 
  if (maxTrack == 0) {
    println("no tracks in ", dataPath(samplePath));
    stop();
  }
  tracks = new String[maxTrack];
  
  for (int i=0; i<maxTrack; i++){
    println(samples[i]);
    tracks[i] = samples[i];
  }
  
  // sets default N-value, initializes windows, starts minim player
  nextTrack(0);  
  // store audio data between frames for pausing & inspection
  Lbuf = new float[N];
  Rbuf = new float[N];
  LnR = new float[N]; 
  level = new float[2];
  
  //fullScreen(P3D);
  size(1920, 1080, P3D); 
  frameRate(frameRt);
  cameraSpeed = TWO_PI / width * 2;
  cursor(CROSS);
  
  /* inherited from source
  pos = new PVector();
  speed = new PVector();
  accelMag = 2;
  */
}

void draw()
{
  lights();
  float far = bsize*gridCount*16; 
  if (PERSPC == true) {
    perspective(PI/2.0, float(width)/float(height), 10.0, far);
  } else {
    ortho(-width*zoom, width*zoom, -height*zoom, height*zoom, 10, far);
  }
  // position camera eye on center of screen AND LEAVE IT THERE
  translate(width/2, height/2, 0);
  rotateX(-cameraRotateY);
  rotateY(-cameraRotateX);
  background(0);
  
  /* inherited from source
  // little box previews motion
  pushMatrix();
  translate(bpos.x, height/2 + bpos.y, bpos.z);
  stroke(255);
  noFill();
  rotateY(atan2(speed.x, speed.y));
  box(bsize);
  popMatrix();
  PVector accel = getMovementDir().rotate(cameraRotateX).mult(accelMag);
  speed.add(accel);
  pos.add(speed);
  speed.mult(0.9);  
  */
  
  // update data buffer when song is playing
  //if ( player.isPlaying() ) {
  updateAudio();
  //}
  color c = color(75,150);  // 50% transparent grey
  if (BOX_ON) {
    noFill();
    stroke(c);
    box(grid*gridCount); 
  } 
  if (GRD_ON) {
    wd.drawGrid(gridCount, grid, c);
    cursor(CROSS);
  } else {
    noCursor();
  }
  if (AUD_ON && player.isPlaying()) {  // under construction
    wd.drawAudioLevels(level[1], level[0], pos, len);
  }
  // try to align PPS plane with orthogonal viewing box
  pushMatrix();
  rotateX(PI/4.0);
  //rotateY(PI/4.0);
  rotateZ(PI/4.0);
  wd.drawPPSData(Lbuf, Rbuf, LnR);  
  popMatrix();
}

void updateAudio() {
  pos = player.position();
  len = player.length();
  if ( player.isPlaying() ) {
    level[1] = player.left.level();
    level[0] = player.right.level();
    float left[] = player.left.toArray();
    float right[] = player.right.toArray();
    arrayCopy(right, 0, Rbuf, 0, N); 
    arrayCopy(left,  0, Lbuf, 0, N); 
    for (int i=0; i < N; i++) {
      LnR[i] = left[i] + right[i];
    }  
  } else if (pos == len) {
    println(tracks[track+1], meta.title(), B, int(S), "Hz"); //int(Fc),    
    nextTrack(track+1); // if @ EOF, load next track
  }
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount(); // +/- 1.0
  zoom = min(max(0.2, zoom + 0.05*e),2.0);
  println("zoom: " + zoom);
}

void mousePressed() {
  
} 

void mouseClicked()
{
  PERSPC = !PERSPC;
}

void mouseMoved() {
  cursor(CROSS);
  cameraRotateX += (mouseX - pmouseX) * cameraSpeed;
  cameraRotateY += (pmouseY - mouseY) * cameraSpeed;
  //cameraRotateY = constrain(cameraRotateY, -HALF_PI, 0);
}

// not in use, inherited from source 
boolean wPressed, sPressed, aPressed, dPressed;
PVector pressedDir = new PVector();
PVector getMovementDir() {
  return pressedDir.copy().normalize();
}

// active hotkeys
void keyPressed()
{
  switch(keyCode) {
  case UP:
    if (wd.tau < wd.ND2) {
      wd.tau += 1; 
      println("tau =", wd.tau);
    } 
    break;
  case DOWN: 
    if (wd.tau > 1) {
      wd.tau -= 1; 
      println("tau =", wd.tau);
    } 
    break;
  case LEFT: 
    if ( player.isPlaying() ) {
      player.skip(-10000);
    } else if ( player.position() == player.length() ) {
      player.rewind();     // restart song
      nextTrack(track);    // reset accumulators
    } else {
      nextTrack(track-1);  // jump to previous track
    }
    break;
  case RIGHT: 
    if ( player.isPlaying() ) {
      player.skip(10000);  // skip forward 10 seconds
    } else {
      nextTrack(track+1);  // jump to next track
    }
    break;
  case ENTER: 
    saveFrame(".\\screens\\"+tracks[track]+"_"+player.position()+".png");
    break;
  }
  switch(key) {
  case '8':
    stroke(255);
    strokeWeight(1);      
    if (N*2 <= B) {
      N *= 2; 
      setNSB(N,S,B);
      wd.setNSB(N,S,B);
    } else {
      println("N at max value:", N);
    } 
    break;
  case '2':
  stroke(255);
    strokeWeight(1);   
    if (N == wd.Nmin) {
      println("N at min value:", N); 
    } else {
      N /= 2; 
      setNSB(N,S,B);
      wd.setNSB(N,S,B);
    }
    break;
  case '4':
    if ( player.isPlaying() ) {
      wd.setNFR(false);
    }     
    break;
  case '6':
    if ( player.isPlaying() ) {
      wd.setNFR(true);
    }     
    break;
  case ' ':
    print("spacebar: "); 
    if ( player.isPlaying() ) {
      print("PAUSE\n"); 
      player.pause();
    } else { 
      print("PLAY\n"); 
      player.play();
    }
    break;
  // snap to orthogonal views:
  case 'w':
    cameraRotateX = 0;
    cameraRotateY = 0;
    wPressed = true;
    pressedDir.y = -1;
    break;
  case 'a':
    cameraRotateX = PI/2.0;
    cameraRotateY = 0;
    aPressed = true;
    pressedDir.x = -1;
    break;
  case 's':
    cameraRotateX = 0;
    cameraRotateY = PI/2.0;
    sPressed = true;
    pressedDir.y = 1;
    break;
  case 'd':
    cameraRotateX = -PI/2.0;
    cameraRotateY = 0;
    dPressed = true;
    pressedDir.x = 1;
    break;
  case 'z':
    cameraRotateX = 0;
    cameraRotateY = -PI/2.0;
    dPressed = true;
    pressedDir.x = 1;
    break;
  case 'x':
    cameraRotateX = 0;
    cameraRotateY = PI;
    dPressed = true;
    pressedDir.x = 1;
    break;
  case 'q':
    cameraRotateX = PI/4.0;
    cameraRotateY = PI/4.0;
    dPressed = true;
    pressedDir.x = 1;
    break;
  case 'e':
    cameraRotateX = PI*3.0/4.0;
    cameraRotateY = PI/4.0;
    dPressed = true;
    pressedDir.x = 1;
    break;
  case 'b':
    BOX_ON = !BOX_ON;
    break;
  case 'g':
    GRD_ON = !GRD_ON;
    break;
  case 'u':
    AUD_ON = !AUD_ON;
    break;
  }
}

// not in use, inherited from source 
void keyReleased() {
  switch(key) {
  case 'w':
    wPressed = false;
    pressedDir.y = sPressed ? 1 : 0;
    break;
  case 's':
    sPressed = false;
    pressedDir.y = wPressed ? -1 : 0;
    break;
  case 'a':
    aPressed = false;
    pressedDir.x = dPressed ? 1 : 0;
    break;
  case 'd':
    dPressed = false;
    pressedDir.x = aPressed ? -1 : 0;
    break;
  }
}
void nextTrack(int _tr) {
  int tr = _tr;
  if ((meta == null) || (player == null) || (tr != track)) {
    if (tr < 0) {
      tr=maxTrack-1;
    } else if ((tr >= maxTrack)) {
      tr=0;
    }
    String txt = sampleFolder+"\\"+samples[tr];
    println(txt); 
    player = minim.loadFile(txt);
    meta = player.getMetaData();
    B = player.bufferSize();
    setNSB( B, player.sampleRate(), B );  // bugs when trying to play files @ 32kHz SR
    if (wd == null ) {
      println("new cmWin"); 
      wd = new cmWin( width, height, B);
    }
    wd.setNSB(N,S,B);
    println(tracks[tr], meta.title(), B, int(S), "Hz"); //int(Fc),
  }
  track=tr;
}  

void setNSB(int _N, float _S, int _B) 
{
  N = _N;
  S = _S;
  B = _B;
  D = int(log(B)/log(2));
  M = int(log(N)/log(2));
  T = float(B)/S;
}

void stop() {
  /*if (in != null) {
    in.close();
  }*/
  if (player != null) {
  player.close();
  }
  exit();
}
