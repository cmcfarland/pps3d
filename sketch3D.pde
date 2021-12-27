/*
 * References: 
https://discourse.processing.org/t/camera-rotation-in-3d-using-mouse/20563 
https://processing.org/examples/orthographic.html
https://www.local-guru.net/blog/2019/1/22/processing-sound-visualizer-explained 
https://www.local-guru.net/ebook/processing-ebook-beta2.pdf
http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.11.9150 
*/
import ddf.minim.*;
import ddf.minim.spi.*;
import ddf.minim.analysis.FFT;
import processing.pdf.*;

Minim minim;
AudioPlayer player;
AudioMetaData meta;
AudioStream in;
MultiChannelBuffer sb;

int grid = 100;
PVector bpos = new PVector();
float bsize = grid;
//float bspeedX, bspeedY, bspeedZ;
//boolean input1, input2, input3, input4;
float cameraRotateX;
float cameraRotateY;
float cameraSpeed;
int gridCount = 20;
PVector pos, speed;
float accelMag;

int B;           // player buffer size, typically 1024 (samples/cycle)
int D;           // log2(B)
int N;           // some fraction of buffer size <= 1024 (samples/cycle)
int M;           // log2(N)
float S;         // sample rate = 41000 Hz (samples/second)
float T;         // Nyquist sample rate = 2048/41000 = 0.25 (seconds/cycle) = 1/(2Fc)
float Fc;        // Nyquist frequency = 1/(4T) ~= 10 Hz @ HIGH-RES, otherwise = 1/(2T)

// relative path to music files
String fn = ".\\samples\\";
int track = 0;
int maxTr;
String[] tracks;
int frameRt = 30;  // # of frames per second to render (24/30)
float zoom = 1.0;

boolean PERSPC = false;
boolean BOX_ON = true;
boolean GRD_ON = true;
boolean AUD_ON = true;
boolean LOGSCL = false;

// define windows to display rendered audio/frequency data
cmWin wd; 
// built-in FFT library for error checking
//FFT fftLib; 
float[] LnR;
float[] Lbuf;
float[] Rbuf;
float levL = 0.0;
float levR = 0.0; 

void setup()
{
  minim = new Minim(this);
  maxTr = 10;
  tracks = new String[maxTr]; // 10
  tracks[0] = "So_Easy.mp3";
  tracks[1] = "Poor_Leno.mp3";
  tracks[2] = "Shivering_Black.mp3";
  tracks[3] = "Lost_On_You.mp3";
  tracks[4] = "Nest_Of_Ravens.mp3";
  tracks[5] = "You_Are_Nature.mp3";
  tracks[6] = "Joanna.mp3";
  tracks[7] = "Cemetery_Beach.mp3";
  tracks[8] = "Into_The_Void.mp3";
  tracks[9] = "Cyclone.mp3"; //"Mirror_Messiah.mp3"; BUGS OUT
  //tracks[10] = "Frozen_Leaves.wav"; // bugs in minim when playing files @ 32kHz SR
  
  // set default N-value, initialize windows class
  nextTrack(0);  
  // store audio data between frames for 3D inspection
  Lbuf = new float[N];
  Rbuf = new float[N];
  LnR = new float[N]; 
  
  //fullScreen(P3D);
  size(1920, 1080, P3D); 
  frameRate(frameRt);
  cameraSpeed = TWO_PI / width * 2;
  //cameraRotateY = -PI/6;
  pos = new PVector();
  speed = new PVector();
  accelMag = 2;
  cursor(CROSS);
}

void draw()
{
  lights();
  float far = bsize*gridCount*16; //map(mouseX, 0, width, 780, 3600);
  //float zoom = map(mouseY, 0, height, 0, camZ*2);
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
  /*
  // little box previews motion
  pushMatrix();
  translate(bpos.x, height/2 + bpos.y, bpos.z);
  stroke(255);
  noFill();
  rotateY(atan2(speed.x, speed.y));
  box(bsize);
  popMatrix();
  */
  PVector accel = getMovementDir().rotate(cameraRotateX).mult(accelMag);
  speed.add(accel);
  pos.add(speed);
  speed.mult(0.9);     
  
  // update buffer data when song is playing
  int posn = player.position();
  int len = player.length();
  float levL = 0.0;
  float levR = 0.0; 
  if ( player.isPlaying() ) {
    levL = player.left.level();
    levR = player.right.level();
    float left[] = player.left.toArray();
    float right[] = player.right.toArray();
    arrayCopy(right, 0, Rbuf, 0, N); 
    arrayCopy(left,  0, Lbuf, 0, N); 
    for (int i=0; i < N; i++) {
      LnR[i] = left[i] + right[i];
    }  
  } 
  // keep eye on center of PPS at all times
  //translate(0, bsize/2-height/2); //
  color c = color(75,150);
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
  if (AUD_ON) {
    wd.drawAudioLevels(levL, levR, posn, len);
  }
  //wd.displayCmds(track, meta.title());
  // enable pausing mid-song to freeze waveforms on screen
  // if paused, re-draw existing buffers to account for moving camera
  pushMatrix();
  // try to align PPS plane with diagonal corners of viewing box
  rotateX(PI/4.0);
  //rotateY(PI/4.0);
  rotateZ(PI/4.0);
  wd.drawPPSData(Lbuf, Rbuf, LnR);  
  popMatrix();
  
}

void updateAudio() {
  if ( player.isPlaying() ) {
    levL = player.left.level();
    levR = player.right.level();
    float left[] = player.left.toArray();
    float right[] = player.right.toArray();
    arrayCopy(right, 0, Rbuf, 0, N); 
    arrayCopy(left,  0, Lbuf, 0, N); 
    for (int i=0; i < N; i++) {
      LnR[i] = left[i] + right[i];
    }  
  } 
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount(); // +/- 1.0
  zoom = min(max(0.2, zoom + 0.05*e),1.0);
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
      if ( player.position() == player.length() ) {
        nextTrack(track+1); // if @ EOF, load next track
      }
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
      tr=maxTr-1;
    } else if ((tr >= maxTr)) {
      tr=0;
    }
    String txt = fn+tracks[tr];
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
  if (in != null) {
    in.close();
  }
  if (player != null) {
  player.close();
  }
}
