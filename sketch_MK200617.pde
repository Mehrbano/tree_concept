// plant a tree in the forest - sabrina 14/06/17
//
  
import java.util.ArrayList;
import java.util.Random;

import com.thomasdiewald.pixelflow.java.DwPixelFlow;
import com.thomasdiewald.pixelflow.java.imageprocessing.filter.DwFilter;
import com.thomasdiewald.pixelflow.java.softbodydynamics.DwPhysics;
import com.thomasdiewald.pixelflow.java.softbodydynamics.constraint.DwSpringConstraint;
import com.thomasdiewald.pixelflow.java.softbodydynamics.constraint.DwSpringConstraint2D;
import com.thomasdiewald.pixelflow.java.softbodydynamics.particle.DwParticle;
import com.thomasdiewald.pixelflow.java.softbodydynamics.particle.DwParticle2D;

import processing.core.PApplet;
import processing.core.PConstants;
import processing.core.PShape;
import processing.opengl.PGraphics2D;
  
  int viewport_w = 1280; //width of the screen
  int viewport_h = 720;  //height of the screen
  int viewport_x = 230;  //placement on the screen
  int viewport_y = 0;    //placement on the screen
  
  // tree objects
  Tree tree1;

  // parameters
  DwPhysics.Param          param_physics      = new DwPhysics.Param();
  DwParticle.Param         param_particles    = new DwParticle.Param();
  DwSpringConstraint.Param param_constraints  = new DwSpringConstraint.Param();
  
  // physics engine
  DwPhysics<DwParticle2D> physics;
 
  // list of all particles
  DwParticle2D[] particles;

  // render targets
  PGraphics2D pg_render;
  PGraphics2D pg_bloom;
  
  // pixelflow context
  DwPixelFlow context;
  
  boolean APPLY_WIND = true;
  
  public void settings() {
    size(viewport_w, viewport_h, P2D);
    smooth(8);
  }

  public void setup() {
    surface.setLocation(viewport_x, viewport_y);

    // main library context
    context = new DwPixelFlow(this);

    // trees
    int tree_idx = 0;
    tree1 = new Tree(tree_idx++);
    tree1.param.LENGTH_LIMIT_MIN = 8; //tree height
    tree1.param.LENGHT_LIMIT_MAX = 120; //tree height
    tree1.param.LENGTH_MULT_BASE = 0.8f; //increase the branches and leaves
    tree1.style.BRANCH_STROKEWIDTH = 12; //branch stroke
    tree1.style.LEAF_RGBA = new float[]{255,128,0, 200}; //color of leaves
    tree1.create(width/2, height-1); //position of the tree

    // particles
    int particles_offset = 0;
    
    param_particles = new DwParticle.Param();
    param_particles.DAMP_BOUNDS          = 0.50f;
    param_particles.DAMP_COLLISION       = 0.5990f; //collision
    param_particles.DAMP_VELOCITY        = 0.920f; //motion of branches 
    
    particles = tree1.setParticles(particles, particles_offset, param_particles);
    particles_offset += tree1.node_count;
    
    param_particles   = new DwParticle.Param();
    param_particles.DAMP_BOUNDS          = 0.50f;
    param_particles.DAMP_COLLISION       = 1.1990f;
    param_particles.DAMP_VELOCITY        = 0.900f;
    
    // physics
    param_physics.GRAVITY = new float[]{ 0, -0.000f }; //gravity force
    param_physics.bounds  = new float[]{ 0, 0, width, height }; //displaying the tree
    param_physics.iterations_collisions = 1; //increasing it slows down
    param_physics.iterations_springs    = 4;
    
    physics = new DwPhysics<DwParticle2D>(param_physics);
    physics.setParticles(particles, particles.length);

    // constraints
    param_constraints.damp_dec = 0.999999f;
    param_constraints.damp_inc = 0.999999f;
    
    tree1.setConstraints(physics, param_constraints);
    tree1.root.particle.enable(false, false, false);
        
    // render targets
    pg_bloom = (PGraphics2D) createGraphics(width, height, P2D);
    pg_bloom.smooth(8);
    
    pg_render = (PGraphics2D) createGraphics(width, height, P2D);
    pg_render.smooth(8);

    pg_render.beginDraw();
    pg_render.background(255);
    pg_render.endDraw();

    frameRate(60);
  }
  
  public void draw(){
    background(255);
    
    updateMouseInteractions();
    
    // add additional forces, e.g. Wind, ...
    int particles_count = physics.getParticlesCount();
    DwParticle[] particles = physics.getParticles();
    if(APPLY_WIND){
      float[] wind = new float[2];
      
      float speed_x = 10; //original was 1
      float speed_y = 1;
      
      float wind_x = -sin(PI/2 + frameCount*0.05f * speed_x) * 0.05f * speed_x;
      float wind_y = -sin(PI/2 + frameCount*0.02f * speed_y) * 0.05f * speed_y;
      
      wind[0] = wind_x;
      wind[1] = wind_y;
      
      for(int i = 0; i < particles_count; i++){
        particles[i].addForce(wind);
      }
    }

    physics.update(1);

    tree1.createShape(this);
    
    pg_render.beginDraw();
    pg_render.noStroke();
    pg_render.fill(255,96); 
    pg_render.rect(0, 0, width, height);

    pg_render.background(0);
    
    pg_render.shape(tree1.shp_tree);
 
    pg_render.endDraw();

    DwFilter filter = DwFilter.get(context);
    filter.bloom.param.mult   = 1.0f; //blurriness and ghostly feeling
    filter.bloom.param.radius = 1; //blurriness radius feeling
    filter.bloom.apply(pg_render, pg_bloom, pg_render);

    blendMode(REPLACE);
    background(0);
    image(pg_render, 0, 0);

    String txt_fps = String.format(getClass().getName()+ " [nodes %d]  [fps %6.2f]", physics.getParticlesCount(), frameRate);
    surface.setTitle(txt_fps);
  }
  
  //////////////////////////////////////////////////////////////////////////////
  // User Interaction
  //////////////////////////////////////////////////////////////////////////////
 
  DwParticle2D particle_mouse = null;
  
  public DwParticle2D findNearestParticle(float mx, float my, float search_radius){
    float dd_min_sq = search_radius * search_radius;
    DwParticle2D particle = null;
    for(int i = 0; i < particles.length; i++){
      float dx = mx - particles[i].cx;
      float dy = my - particles[i].cy;
      float dd_sq =  dx*dx + dy*dy;
      if( dd_sq < dd_min_sq){
        dd_min_sq = dd_sq;
        particle = particles[i];
      }
    }
    return particle;
  }
  
  public ArrayList<DwParticle> findParticlesWithinRadius(float mx, float my, float search_radius){
    float dd_min_sq = search_radius * search_radius;
    ArrayList<DwParticle> list = new ArrayList<DwParticle>();
    for(int i = 0; i < particles.length; i++){
      float dx = mx - particles[i].cx;
      float dy = my - particles[i].cy;
      float dd_sq =  dx*dx + dy*dy;
      if(dd_sq < dd_min_sq){
        list.add(particles[i]);
      }
    }
    return list;
  }
      // deleting springs/constraints between particles
  public void updateMouseInteractions(){
    if(DELETE_SPRINGS){
      ArrayList<DwParticle> list = findParticlesWithinRadius(mouseX, mouseY, DELETE_RADIUS);
      for(DwParticle tmp : list){
        tmp.enableAllSprings(false);
        tmp.collision_group = physics.getNewCollisionGroupId();
        tmp.rad_collision = tmp.rad;
      }
    } else {
      if(particle_mouse != null){
        float[] mouse = {mouseX, mouseY};
        particle_mouse.moveTo(mouse, 0.2f);
      }
    }
  }
  
  boolean DELETE_SPRINGS = false;
  float   DELETE_RADIUS  = 10;

  public void mousePressed(){
    if(mouseButton == RIGHT ) DELETE_SPRINGS = true;
    
    if(!DELETE_SPRINGS){
      particle_mouse = findNearestParticle(mouseX, mouseY, 100);
      if(particle_mouse != null) particle_mouse.enable(false, false, false);
    }
  }
  
  public void mouseReleased(){
    if(particle_mouse != null && !DELETE_SPRINGS){
      if(mouseButton == LEFT  ) particle_mouse.enable(true, true,  true );
      if(mouseButton == CENTER) particle_mouse.enable(false, false, false);
      particle_mouse = null;
    }
    if(mouseButton == RIGHT ) DELETE_SPRINGS = false;
  }
  
  public void keyReleased(){
  }
  
  static class Tree{
    
    public static class Param{
      public Random rand_tree_angle  = new Random(1);
      public Random rand_tree_length = new Random(10);
      public Random rand_leaf        = new Random(0);
      
      //tree branches and leaves
      public float ANGLE_LIMIT_RANGE = PI/5.0f; //spread of the tree
      public int   DEPTH_LIMIT_MAX   = 15; //
      public int   LENGTH_LIMIT_MIN  = 8;
      public int   LENGHT_LIMIT_MAX  = 8;
      
      public float LENGTH_MULT_BASE  = 0.76f;
      public float LENGTH_MULT_RANGE = 0.22f;
      
      public float LEAF_CHANCE  = 0.1f; //by decreasing this we get more branches
    }
    
    public static class Style{
      public float   BRANCH_STROKEWIDTH = 15;
    
      public float   LEAF_RADIUS  = 20; //leaf radius
      public float[] LEAF_RGBA  = {255, 128, 0, 150};
    }
    
    
    public int idx = 0;
    public int MAX_DEPTH = 0;
    public float MAX_LENGTH = 0;
    public int node_count = 0;
    
    public Param param = new Param();
    public Style style = new Style();
    
    public Node root;
    
    public PShape shp_tree;
 
    public Tree(int idx){
      this.idx = idx;
    }
    
    public void create(float px, float py){
      param.rand_tree_angle = new Random(0);
      param.rand_tree_length = new Random(0);
      node_count = 0;
      root = new Node(this, px, py, -PI/2, param.LENGHT_LIMIT_MAX);
    }
    
    public void display(PGraphics2D canvas){
      param.rand_leaf = new Random(0);
      root.display(canvas);
    }
    
    public int nodeCount(){
      return node_count;
    }
    
    public DwParticle2D[] setParticles(DwParticle2D[] particles, int offset, DwParticle.Param param){
      // dynamically resize array if required
      if(particles == null || particles.length < offset + node_count){
        DwParticle2D[] particles_tmp = new DwParticle2D[offset + node_count];
        if(particles != null){
          System.arraycopy(particles, 0, particles_tmp, 0, offset);
        }
        particles = particles_tmp;
      }
      if(root != null) root.setParticles(particles, offset, param);
      return particles;
    }
    
    public void setConstraints(DwPhysics<DwParticle2D> physics, DwSpringConstraint.Param param){
      if(root != null) root.setConstraints(physics, param);
    }
    
    
    public void createShape(PApplet papplet){
      param.rand_leaf = new Random(0);
      if(shp_tree == null){
        shp_tree = papplet.createShape(PConstants.GROUP);
      }
      
      root.createShape(papplet, shp_tree);
    }
    
  }
  
  

  static class Node{

    final Tree tree;
    Node parent = null;
    
    Node child1 = null;
    Node child2 = null;
    
    boolean is_leaf = false;
    boolean is_root = false;

    int idx = 0;
    int depth = 0;
    float angle, length;
    DwParticle2D particle;

    public void initParticle(float px, float py){
      float radius = length/2;
      float radius_collision = Math.max(length/3, 2);

      particle = new DwParticle2D(idx);
      particle.setPosition(px, py);
      particle.setMass(1);
      particle.setRadius(radius);
      particle.setRadiusCollision(radius_collision);
      particle.setCollisionGroup(tree.idx); 
    }
    
    
    public Node(Tree tree, float px, float py, float angle, float length){
      this.tree = tree;
      this.idx = tree.node_count++;
      this.angle = angle;
      this.length = length;
      this.is_leaf = length < tree.param.LENGTH_LIMIT_MIN || depth > tree.param.DEPTH_LIMIT_MAX;
      this.is_root = parent == null;

      initParticle(px, py);
      
      child1 = new Node(tree, this, 0);
    }
    

    public Node(Tree tree, Node parent, float angle_scale){
      this.tree = tree;
  
      this.parent = parent;
      this.depth = parent.depth + 1;
      this.idx = tree.node_count++;
      
      float rand_angle  = tree.param.rand_tree_angle.nextFloat();
      float rand_length = tree.param.rand_tree_length.nextFloat();
       
      float length_mult = tree.param.LENGTH_MULT_BASE + (rand_length * 2 - 1) * tree.param.LENGTH_MULT_RANGE;
      length_mult = Math.min(Math.max(length_mult, 0), 1);
      
      this.length = parent.length * length_mult;
      this.angle  = parent.angle + rand_angle * angle_scale;
      
      this.is_leaf = length < tree.param.LENGTH_LIMIT_MIN || depth > tree.param.DEPTH_LIMIT_MAX;
      this.is_root = parent == null;
      
      float px = parent.particle.cx + cos(angle) * length;
      float py = parent.particle.cy + sin(angle) * length;
      
      initParticle(px, py);
      
      tree.MAX_DEPTH  = Math.max(tree.MAX_DEPTH , depth);
      tree.MAX_LENGTH = Math.max(tree.MAX_LENGTH, length);
      
      if(!is_leaf){
        child1 = new Node(tree, this, -tree.param.ANGLE_LIMIT_RANGE); //main branch to one direction
        child2 = new Node(tree, this, +tree.param.ANGLE_LIMIT_RANGE); //main branch to another direction
      }
    }
    
    public int nodeCount(int count){
      if(child1 != null) count = child1.nodeCount(count);
      if(child2 != null) count = child2.nodeCount(count);
      return count + 1;
    }
    
    public void setParticles(DwParticle2D[] particles, int offset, DwParticle.Param param){
      particle.setParamByRef(param);
      particles[offset + idx] = particle;
      if(child1 != null) child1.setParticles(particles, offset, param);
      if(child2 != null) child2.setParticles(particles, offset, param);
    }
    
    public void setConstraints(DwPhysics<DwParticle2D> physics, DwSpringConstraint.Param param){
      Node othr = parent;
      int counter_max = 2;
      int counter = 0;
      while(othr != null && counter < counter_max){
        DwSpringConstraint2D.addSpring(physics, othr.particle, this.particle, param);
        othr = othr.parent;
        counter++;
      }
      
      if(parent != null){
        DwSpringConstraint2D.addSpring(physics, parent.particle, this.particle, param);
        Node sibling = parent.child1 != this ? parent.child1 : parent.child2;
        if(sibling != null){
          DwSpringConstraint2D.addSpring(physics, sibling.particle, this.particle, param);
        }
      }
      
      if(child1 != null) child1.setConstraints(physics, param);
      if(child2 != null) child2.setConstraints(physics, param);
    }
    
    PShape shp_branch;
    PShape shp_leaf;
    
    public void createShape(PApplet papplet, PShape shp_tree){

      float depthn  = (this.depth +1) / (float) (tree.MAX_DEPTH +1);
      float lengthn = (this.length+1) / (float) (tree.MAX_LENGTH+1);
      float parent_lengthn = lengthn;
      if(parent != null){
        parent_lengthn = (parent.length+1) / (float) (tree.MAX_LENGTH+1);
      }
      
      if(is_leaf){
        float chance = tree.param.rand_leaf.nextFloat();
        if(chance < tree.param.LEAF_CHANCE){
          float radius = Math.max(depthn * tree.style.LEAF_RADIUS, 1);
          DwParticle2D pb = parent.particle;  
          if(shp_leaf == null){
            
            int r = (int) (tree.style.LEAF_RGBA[0] * depthn);
            int g = (int) (tree.style.LEAF_RGBA[1] * depthn);
            int b = (int) (tree.style.LEAF_RGBA[2] * depthn);
            int a = (int) (tree.style.LEAF_RGBA[3]         );
            int argb = a << 24 | r << 16 | g << 8 | b;
            
            shp_leaf = papplet.createShape(PConstants.ELLIPSE, 0, 0, radius, radius); //size of the leaf
            shp_leaf.setStroke(false); //stroke of the leaf
            shp_leaf.setFill(true); //fill of the leaf
            shp_leaf.setFill(argb); //these are given above
               shp_tree.addChild(shp_leaf); 
          }
          shp_leaf.resetMatrix();
          shp_leaf.translate(pb.cx, pb.cy); //this is placing the leaves where the branches are
        }
      } else {
        
        float sw_pa = Math.max(lengthn        * tree.style.BRANCH_STROKEWIDTH, 1);
        float sw_pb = Math.max(parent_lengthn * tree.style.BRANCH_STROKEWIDTH, 1);
        
        if(!is_root){
          DwParticle2D pa = particle;
          DwParticle2D pb = parent.particle;
          
          if(shp_branch == null){
            shp_branch = papplet.createShape();
            shp_branch.beginShape(PConstants.LINES);
            shp_branch.strokeCap(PConstants.ROUND);

            shp_branch.strokeWeight(sw_pb);
            shp_branch.stroke(parent_lengthn * 12); //smothness of the rendering
            shp_branch.vertex(0, 20); //this is changing the angle of the branch ... I like this one original is 0
            shp_branch.stroke(lengthn * 128); //some color changes
            shp_branch.vertex(length, 0); //produces some extra lines original is 0
            shp_branch.endShape();
            shp_tree.addChild(shp_branch);
          }
          
          float dx = pa.cx - pb.cx;
          float dy = pa.cy - pb.cy;
          float dd = (float) Math.sqrt(dx*dx + dy*dy);
          float angle = PApplet.atan2(dy, dx);
          
          shp_branch.resetMatrix();
          shp_branch.scale(dd/length);
          shp_branch.rotate(angle);
          shp_branch.translate(pb.cx, pb.cy); //the alignment of branch element
        }
        
      }
      
      if(child1 != null) child1.createShape(papplet, shp_tree);
      if(child2 != null) child2.createShape(papplet, shp_tree);
    }
    
        //*** canvas display ***//
        // what is the importance //
    public void display(PGraphics2D canvas){
      float depthn  = (this.depth +1) / (float) (tree.MAX_DEPTH +1);
      float lengthn = (this.length+1) / (float) (tree.MAX_LENGTH+1);
      float parent_lengthn = lengthn;
      if(parent != null){
        parent_lengthn = (parent.length+1) / (float) (tree.MAX_LENGTH+1);
      }
      
      if(is_leaf){
        float chance = tree.param.rand_leaf.nextFloat();
        if(chance < tree.param.LEAF_CHANCE){
          float radius = Math.max(depthn * tree.style.LEAF_RADIUS, 1);
          DwParticle2D pb = parent.particle;  
          canvas.fill(tree.style.LEAF_RGBA[0] * depthn, tree.style.LEAF_RGBA[1] * depthn, tree.style.LEAF_RGBA[2] * depthn, tree.style.LEAF_RGBA[3]);
          canvas.noStroke();
          canvas.ellipse(pb.cx, pb.cy, radius, radius);
        }
      } else {
        
        float sw_pa = Math.max(lengthn        * tree.style.BRANCH_STROKEWIDTH, 1);
        float sw_pb = Math.max(parent_lengthn * tree.style.BRANCH_STROKEWIDTH, 1);
        
        if(!is_root){
          DwParticle2D pa = particle;
          DwParticle2D pb = parent.particle;
          canvas.noFill(); 
          canvas.beginShape(PConstants.LINES);
          canvas.stroke(lengthn * 128);
          canvas.strokeWeight(sw_pa);
          canvas.vertex(pa.cx, pa.cy);
          canvas.vertex(pb.cx, pb.cy);
          canvas.endShape();
        }
      }
      if(child1 != null) child1.display(canvas);
      if(child2 != null) child2.display(canvas);
    }
  }