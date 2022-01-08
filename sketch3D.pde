/*
 * References: 
https://discourse.processing.org/t/camera-rotation-in-3d-using-mouse/20563 
https://forum.processing.org/two/discussion/1747/reading-filesnames-from-a-folder 
https://docs.oracle.com/javase/7/docs/api/java/io/File.html
https://processing.org/examples/orthographic.html 
http://code.compartmental.net/minim/audiolistener_audiolistener.html
*/
import ddf.minim.*;
import ddf.minim.spi.*; // for AudioStream
import java.io.File;    // for scanning samples directory
import org.gamecontrolplus.*;

ControlIO control; 
ControlDevice conn3d;
Minim minim;
AudioPlayer player;
AudioMetaData meta;
AudioStream stream; // reads from input source of soundcard (set in Control Panel)
//AudioSource source;
//AudioOut    output;
AudioInput  input;  // wrapper for AudioStream, needed for addListener
renderAudio render; // defines windows for rendered audio/frequency data
updateAudio update; // audio listener class implementation
// expects a subfolder called 'samples' containing mp3 or wav files
// defaults to looking in a subfolder called 'data', hence the '..'
String samplePath = "..\\samples";
File sampleFolder; 
String[] samples;
int track = 0;      // current track being loaded / played
int maxTrack = 0;   // default until directory scanned
int B;           // player buffer size, typically 1024 (samples/cycle)
int D;           // log2(B)
int N;           // some fraction of buffer size <= B
int M;           // log2(N)
float S;         // sample rate, typically 41000 Hz (samples/second)
float T;         // Nyquist sample rate = 2048/41000 = 0.25 (seconds/cycle) = 1/(2Fc)
float Fc;        // Nyquist frequency = 1/(4T) ~= 10 Hz @ HIGH-RES, otherwise = 1/(2T)

int grid = 80;
int gridCount = 20;
float bsize = grid;
float cameraRotateX;
float cameraRotateY;
float cameraSpeed;
int frameRt = 30;   // # of frames per second to render (24/30)
float zoom = 1.0;

boolean PAUSED = false;
boolean PERSPC = false;
boolean BOX_ON = true;
boolean GRD_ON = true;
boolean AUD_ON = true;
boolean LOGSCL = false;
boolean STREAM = false;

class updateAudio implements AudioListener {
  private float[] left;
  private float[] right;
  
  updateAudio() {
    left = null; 
    right = null;
  }
  // store last available audio data for pausing & inspection
  public synchronized void samples(float[] sampL, float[] sampR) {
    if (PAUSED == false) {
      left = sampL;
      right = sampR;    
    }  
  }
  public synchronized void samples(float[] samp) {
    if (PAUSED == false) {
      left = samp;  
    }  
  }
  synchronized void draw() {
    if (AUD_ON) {
      // try to align PPS planes with orthogonal viewing box
      pushMatrix();
      rotateX(PI/4.0);
      //rotateY(PI/4.0);
      rotateZ(PI/4.0);
      render.drawPPSData(left, right);  
      popMatrix();
    } else {
      // render frequency domain data
      pushMatrix();
      render.drawFFTData(left, right, LOGSCL);
      popMatrix();
    }
  } 
  void reset() {
    left = null;
    right = null;
  }
}

void setup()
{
  findAudio();         // look for subdirectory of samples, otherwise use recording source
  //findJoystick();      // in progress
  size(960, 540, P3D); //fullScreen(P3D);
  frameRate(frameRt);
  cameraSpeed = TWO_PI / width * 2;
  cursor(CROSS);
}

void draw()
{
  lights();
  float far = bsize*gridCount*20; 
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
  
  color c = color(75,150);  // 50% transparent grey
  if (BOX_ON) {
    noFill();
    stroke(c);
    box(grid*gridCount); 
  } 
  if (GRD_ON) {
    render.drawGrid(gridCount, grid, c);
    cursor(CROSS);
  } else {
    noCursor();
  }
  // update player levels & elapsed time when song is playing
  if ( player != null || input != null) { // (in progress)
    if ( player.isPlaying() ) {
      elapsedTime();     // apply auto-scaling
    }
    update.draw();
  }
}

void findAudio() {
  // bugs in minim when playing files @ 32kHz sample rate
  minim = new Minim(this); 
  update = new updateAudio();
  sampleFolder = new File(dataPath(samplePath));
  if (sampleFolder != null) {
    samples = sampleFolder.list(); 
  }
  if (samples != null) {
    maxTrack = samples.length;
  } 
  if (maxTrack > 0) {
    // list all files in sample directory
    for (int i=0; i<maxTrack; i++){
      println(samples[i]);
    } 
    // sets default N-value, initializes renderer, starts player at track 0
    loadTrack(0);    
  } else if (maxTrack == 0) { 
    // use line in if no files to play
    println("no tracks in ", dataPath(samplePath), "trying line in..."); 
    loadStream();
  } 
}
void elapsedTime() {
  int pos = player.position();
  int len = player.length();
  if (pos == len) {
    //println(samples[track+1], meta.title(), B, int(S), "Hz"); //int(Fc),    
    loadTrack(track+1); // if @ EOF, load next track
  }
}

void loadStream() {
  // delete existing listener, if any
  if ( player != null && update != null ) {
    player.removeListener( update );
  }
  /*
  if (stream == null) {
    // try to open stream, or report error
    stream = minim.getInputStream(2,1024,44100.0,16);
  }
  stream.addListener( update ); // FAIL
  stream.open();
  */
  // delete existing listener, if any
  if (update != null) {
    if ( player != null) {
      //player.close();
      player.removeListener( update );
    }
    if ( input != null) {
      input.close();
      input.removeListener( update );
    }
    update.reset();
  }
  if (input == null) {
    input = minim.getLineIn();
  }
  input.addListener( update );
  STREAM = (input != null);
  PAUSED = false;
  println("STREAM =", STREAM);
}

void loadTrack(int _tr) {
  int tr = _tr;
  // delete existing listener, if any
  if (update != null) {
    if ( player != null) {
      //player.close();
      player.removeListener( update );
    }
    if ( input != null) {
      input.close();
      input.removeListener( update );
    }
    update.reset();
  }
  // start at beginning of playlist and wrap around
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
    if (render == null ) {
      println("new Audio Renderer"); 
      render = new renderAudio( width, height, B );
    }
    render.setNSB(N,S,B);
  }
  println(samples[tr], meta.title(), B, int(S), "Hz"); //int(Fc),
  track=tr;
  PAUSED = false;
  // enable synchronized sample buffering & drawing
  player.addListener( update );
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

// active hotkeys
void keyPressed()
{
  switch(keyCode) {
  case UP:
    if (render.tau < render.ND2) {
      render.tau += 1; 
      println("tau =", render.tau);
    } 
    break;
  case DOWN: 
    if (render.tau > 1) {
      render.tau -= 1; 
      println("tau =", render.tau);
    } 
    break;
  case LEFT: 
    if ( player.isPlaying() ) {
      player.skip(-10000);
    } else if ( player.position() == player.length() ) {
      player.rewind();     // restart song
      loadTrack(track);    // reset accumulators
    } else {
      loadTrack(track-1);  // jump to previous track
    }
    break;
  case RIGHT: 
    if ( player.isPlaying() ) {
      player.skip(10000);  // skip forward 10 seconds
    } else {
      loadTrack(track+1);  // jump to next track
    }
    break;
  case ENTER: 
    saveFrame(".\\screens\\"+samples[track]+"_"+player.position()+".png");
    break;
  }
  switch(key) {
  case '8':
    stroke(255);
    strokeWeight(1);      
    if (N*2 <= B) {
      N *= 2; 
      setNSB(N,S,B);
      render.setNSB(N,S,B);
    } else {
      println("N at max value:", N);
    } 
    break;
  case '2':
  stroke(255);
    strokeWeight(1);   
    if (N == render.Nmin) {
      println("N at min value:", N); 
    } else {
      N /= 2; 
      setNSB(N,S,B);
      render.setNSB(N,S,B);
    }
    break;
  case '4':
    if ( player.isPlaying() ) {
      render.setNFR(false);
    }     
    break;
  case '6':
    if ( player.isPlaying() ) {
      render.setNFR(true);
    }     
    break;
  case ' ':
    print("spacebar: "); 
    if ( player.isPlaying() ) {
      print("PAUSE\n"); 
      player.pause();
      PAUSED = true;
    } else { 
      print("PLAY\n"); 
      player.play();
      PAUSED = false;
    }
    println("PAUSED =", PAUSED);
    break;
  // snap to orthogonal views:
  case 'w':
    cameraRotateX = 0;
    cameraRotateY = 0;
    break;
  case 'a':
    cameraRotateX = PI/2.0;
    cameraRotateY = 0;
    break;
  case 's':
    cameraRotateX = 0;
    cameraRotateY = PI/2.0;
    break;
  case 'd':
    cameraRotateX = -PI/2.0;
    cameraRotateY = 0;
    break;
  case 'z':
    cameraRotateX = 0;
    cameraRotateY = -PI/2.0;
    break;
  case 'x':
    cameraRotateX = 0;
    cameraRotateY = PI;
    break;
  case 'q':
    cameraRotateX = PI/4.0;
    cameraRotateY = PI/4.0;
    break;
  case 'e':
    cameraRotateX = PI*3.0/4.0;
    cameraRotateY = PI/4.0;
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
  case 'l':
    LOGSCL = !LOGSCL;
    break;
  case 't':
    if (player != null) {
      player.close(); 
    }
    loadStream();
    break;
  case 'f':
    if (input != null) {
      input.close(); 
      STREAM = false;
      println("STREAM =", STREAM);
    }
    loadTrack(track);
    break;
  }
}

void keyReleased() {
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

void findJoystick() {
  /* 3D joystick -- IN PROGRESS */
  control = ControlIO.getInstance(this);
  println(control.getDevices());
  conn3d = control.getDevice("3Dconnexion KMJ Emulator");
  println(conn3d.getInputs());
  println(conn3d.getTypeID() + " " + conn3d.getTypeName());
  String tab = "";
  println(conn3d.buttonsToText(tab));
  println(conn3d.slidersToText(tab));  
}

void stop() {
  if (stream != null) {
    stream.close();
  }
  if (player != null) {
  player.close();
  }
  exit();
}
