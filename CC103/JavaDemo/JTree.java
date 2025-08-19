import javax.swing.JFrame;
import javax.swing.JTree;
import javax.swing.tree.DefaultMutableTreeNode;

public class JTree {
    public static void main(String[] args) {
        JFrame f = new JFrame("Sample JTree");
        f.setSize(400, 400);
        f.setVisible(true);

        DefaultMutableTreeNode thisPC = new DefaultMutableTreeNode("This PC");
        DefaultMutableTreeNode desk = new DefaultMutableTreeNode("Desktop");
        DefaultMutableTreeNode dl = new DefaultMutableTreeNode("Downloads");
        DefaultMutableTreeNode doc = new DefaultMutableTreeNode("Documents");
        DefaultMutableTreeNode pic = new DefaultMutableTreeNode("Pictures");
        DefaultMutableTreeNode mus = new DefaultMutableTreeNode("Music");
        DefaultMutableTreeNode vid = new DefaultMutableTreeNode("Videos");
        thisPC.add(desk);
        thisPC.add(dl);
        thisPC.add(doc);
        thisPC.add(pic);
        thisPC.add(mus);
        thisPC.add(vid);

        JTree jt = new JTree(thisPC);
        f.add(jt);
    }   
}
