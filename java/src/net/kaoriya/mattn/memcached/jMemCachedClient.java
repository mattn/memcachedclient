package net.kaoriya.mattn.memcached;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Future;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.JTextField;
import javax.swing.JTextPane;
import javax.swing.border.LineBorder;
import javax.swing.text.Document;
import javax.swing.text.MutableAttributeSet;
import javax.swing.text.SimpleAttributeSet;
import javax.swing.text.StyleConstants;

import net.spy.memcached.MemcachedClient;


public class jMemCachedClient extends JFrame {
	/** serialize version UID. */
	private static final long serialVersionUID = -1L;

	/** memcached client. */
	private MemcachedClient mc;

	/** attribute set of JTextPane. */
	private Map<String, MutableAttributeSet> attrs = new HashMap<String, MutableAttributeSet>();

	/** command history. */
	List<String> cmds = new ArrayList<String>();

	/** command history index. */
	int cmd_cur = -1;

	/**
	 * constructor of jMemCachedClient.
	 * @throws IOException throw when couldn't create memcached client.
	 */
	public jMemCachedClient() throws IOException {
		mc = new MemcachedClient(new InetSocketAddress("127.0.0.1", 11211));

		attrs.put("command", new SimpleAttributeSet());
		StyleConstants.setForeground(attrs.get("command"), Color.BLUE);
		attrs.put("data", new SimpleAttributeSet());
		StyleConstants.setForeground(attrs.get("data"), Color.BLACK);
		attrs.put("error", new SimpleAttributeSet());
		StyleConstants.setForeground(attrs.get("error"), Color.RED);

		this.setLayout(new BorderLayout());

		GridBagConstraints gbc = new GridBagConstraints();
		gbc.gridwidth = 1;
		gbc.gridheight = 10;
		gbc.weightx = 1.0d;

		JPanel panel = new JPanel();
		GridBagLayout layout = new GridBagLayout();
		panel.setLayout(layout);

		final JTextPane textpane = new JTextPane();
		textpane.setEditable(false);
		textpane.setMinimumSize(new Dimension(400, 400));
		textpane.setBorder(new LineBorder(Color.GRAY));
		gbc.weighty = 1.0d;
		gbc.insets = new Insets(5, 5, 5, 5);
		gbc.fill = GridBagConstraints.BOTH;
		layout.setConstraints(textpane, gbc);
		panel.add(textpane);

		final JTextField textfield = new JTextField();
		textfield.setFont(new Font("monospace", Font.PLAIN, textfield.getFont().getSize()));
		gbc.gridy = 10;
		gbc.weighty = 0.0d;
		layout.setConstraints(textfield, gbc);
		textfield.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent ev) {
				try {
					String text = textfield.getText();

					if (cmd_cur >= 0 && text.equals(cmds.get(cmd_cur))) {
						cmds.remove(cmds.size() - 1);
					}

					cmds.add(0, text);
					cmd_cur = -1;

					Document doc = textpane.getDocument(); 
					doc.insertString(
						doc.getLength(),
						text + "\n",
						attrs.get("command"));

					Matcher matcher = Pattern.compile("^(get|set|delete)\\s+(\\S+)((\\s+)(\\S+))?").matcher(text);
					if (matcher.matches()) {
						if (matcher.group(1).toLowerCase().equals("get") && matcher.start(2) > 0) {
							Object val = mc.get(matcher.group(2));
							if (val != null) {
								doc.insertString(
										doc.getLength(),
										val.toString() + "\n",
										attrs.get("data"));
							} else {
								doc.insertString(
										doc.getLength(),
										"Not found.\n",
										attrs.get("error"));
							}
						} else
						if (matcher.group(1).toLowerCase().equals("set") && matcher.start(5) > 0) {
							Future ret = mc.set(matcher.group(2), 0, matcher.group(5));
							if (!ret.isCancelled()) {
								doc.insertString(
										doc.getLength(),
										"Ok.\n",
										attrs.get("data"));
							} else {
								doc.insertString(
										doc.getLength(),
										"Not found.\n",
										attrs.get("error"));
							}
						} else
						if (matcher.group(1).toLowerCase().equals("delete") && matcher.start(2) > 0) {
							Object val = mc.delete(matcher.group(2));
							if (val != null) {
								doc.insertString(
										doc.getLength(),
										val.toString() + "\n",
										attrs.get("data"));
							} else {
								doc.insertString(
										doc.getLength(),
										"Not found.\n",
										attrs.get("error"));
							}
						} else {
							doc.insertString(
									doc.getLength(),
									"Unknown command '" + text + "'.\n",
									attrs.get("error"));
						}
					} else {
						doc.insertString(
								doc.getLength(),
								"Unknown command '" + text + "'.\n",
								attrs.get("error"));
					}
				} catch (Throwable e) {
					e.printStackTrace();
				}
				textfield.setText("");
			}
		});
		textfield.addKeyListener(new KeyAdapter() {
			public void keyReleased(KeyEvent ev) {
				if (ev.getKeyCode() == KeyEvent.VK_UP) {
					if (cmd_cur < cmds.size() - 1) {
						cmd_cur++;
					}
					if (cmds.get(cmd_cur).length() > 0) {
						textfield.setText(cmds.get(cmd_cur));
					}
				} else
				if (ev.getKeyCode() == KeyEvent.VK_DOWN) {
					if (cmd_cur >= 0) {
						cmd_cur--;
					}
					if (cmd_cur >= 0 && cmds.get(cmd_cur).length() > 0) {
						textfield.setText(cmds.get(cmd_cur));
					} else {
						textfield.setText("");
					}
				}
			}
		});
		panel.add(textfield);

		this.getContentPane().add(panel, BorderLayout.CENTER);

		this.addWindowListener(new WindowAdapter() {
			public void windowOpened(WindowEvent e) {
				textfield.grabFocus();
			}
		});
	}

	/**
	 * main entry.
	 * @param args command-line arguments.
	 * @throws IOException throw when couldn't create memcached client.
	 */
	public static void main(String[] args) throws IOException {
		jMemCachedClient jmcc = new jMemCachedClient();
		jmcc.setTitle("MemCachedClient");
		jmcc.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		jmcc.setSize(400, 500);
		jmcc.setVisible(true);
	}
}
